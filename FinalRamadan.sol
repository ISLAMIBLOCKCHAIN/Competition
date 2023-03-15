// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

contract ramadanCompetition {
    address public admin = 0xB495EfB6d04400342919d0D2c0E6C120Ad814500;

    struct Node {
        address player;
        uint256 score;
        address next;
        address prev;
    }

    struct Player {
        uint256 score;
        bool exists;
        uint256 index;
        uint256 lastSubmission;
        uint256 daysPlayed;
    }

    mapping(address => Player) public players;
    mapping(address => bool) private inTopPlayers;
    mapping(address => bool) private eligiblePlayers; // players who played more than 24 days
    mapping(address => Node) public nodes;
    address public head;

    uint256 public maxTopPlayers = 10;
    uint256 public numPlayers;
    uint256 public twentyFour;

    event ScoreUpdated(
        address indexed player,
        uint256 score,
        uint256 submission
    );
    event SelectedPlayer(address player, uint256 daysPlayed, uint256 index);
    event PlayerAddedToTopPlayers(
        address Player,
        uint256 Score,
        uint256 Submission
    );
    event PlayerRemovedFromTopPlayers(address Player, uint256 Score);

    function isScoreSubmittedToday(address _player) public view returns (bool) {
        require(players[_player].exists, "Player doesn't exist.");
        uint256 lastSubmission = players[_player].lastSubmission;
        uint256 currentDay = block.timestamp / 1 days; // Round down to the nearest day
        uint256 lastSubmissionDay = lastSubmission / 1 days; // Round down to the nearest day
        return (currentDay == lastSubmissionDay);
    }

    function updateScore(address _player, uint256 score) public {
        require(msg.sender == admin, "Not authorized!");
        require(score >= 0, "Score must be non-negative.");

        Player storage player = players[_player];

        if (!player.exists) {
            player.exists = true;
            player.score = score;
            player.lastSubmission = block.timestamp;
            player.daysPlayed = 1;

            uint256 newIndex = insertPlayer(_player, score);
            player.index = newIndex;
            numPlayers++;
        } else {
            require(
                !isScoreSubmittedToday(_player),
                "Can't update score before next day"
            );

            player.lastSubmission = block.timestamp;
            uint256 oldScore = player.score;
            uint256 newScore = oldScore + score;
            player.score = newScore;
            player.daysPlayed++;

            // Update the eligibility of the player
            if (player.daysPlayed >= 24 && player.index >= maxTopPlayers) {
                eligiblePlayers[_player] = true;
                twentyFour++;
            } else {
                eligiblePlayers[_player] = false;
            }

            // Update the linked list to maintain the order
            updatePlayerPositionInLinkedList(_player, newScore);

            emit ScoreUpdated(_player, score, player.lastSubmission);
        }
    }

    function updatePlayerPositionInLinkedList(address _player, uint256 newScore)
        internal
    {
        // Remove the player from the current position in the linked list
        if (nodes[_player].prev != address(0)) {
            nodes[nodes[_player].prev].next = nodes[_player].next;
        } else {
            head = nodes[_player].next;
        }
        if (nodes[_player].next != address(0)) {
            nodes[nodes[_player].next].prev = nodes[_player].prev;
        }

        // Reinsert the player in the new position based on the updated score
        uint256 newIndex = insertPlayer(_player, newScore);
        players[_player].index = newIndex;
    }

    function isInLinkedList(address _player) public view returns (bool) {
        return nodes[_player].player == _player;
    }

    function insertPlayer(address _player, uint256 _score)
        internal
        returns (uint256)
    {
        uint256 newIndex = 0;
        if (head == address(0) || _score > nodes[head].score) {
            nodes[_player] = Node(_player, _score, head, address(0));
            if (head != address(0)) {
                nodes[head].prev = _player;
                players[head].index++; // Update the index of the affected player
            }
            head = _player;
        } else {
            address currentNode = head;
            while (
                nodes[currentNode].next != address(0) &&
                nodes[nodes[currentNode].next].score >= _score
            ) {
                currentNode = nodes[currentNode].next;
                newIndex++;
            }

            nodes[_player] = Node(
                _player,
                _score,
                nodes[currentNode].next,
                currentNode
            );
            if (nodes[currentNode].next != address(0)) {
                nodes[nodes[currentNode].next].prev = _player;
                players[nodes[currentNode].next].index++; // Update the index of the affected player
            }
            nodes[currentNode].next = _player;
        }

        // Update the index values for all the players affected by the insertion
        address currentNodeToUpdate = nodes[_player].next;
        while (currentNodeToUpdate != address(0)) {
            players[currentNodeToUpdate].index++;
            currentNodeToUpdate = nodes[currentNodeToUpdate].next;
        }

        return newIndex;
    }

    function getTopPlayers()
        public
        view
        returns (address[] memory, uint256[] memory)
    {
        uint256 count;
        if (maxTopPlayers > numPlayers) {
            count = numPlayers;
        } else {
            count = maxTopPlayers;
        }
        address[] memory playerList = new address[](count);
        uint256[] memory scoreList = new uint256[](count);

        address currentNode = head;
        for (uint256 i = 0; i < count && currentNode != address(0); i++) {
            playerList[i] = currentNode;
            scoreList[i] = nodes[currentNode].score;
            currentNode = nodes[currentNode].next;
        }

        return (playerList, scoreList);
    }

    function getRandomUsers(uint256 maxCount)
        public
        view
        returns (address[] memory)
    {
        require(maxCount > 0, "Max count must be greater than 0");

        // Create an array to store the eligible players
        address[] memory selectedPlayers = new address[](maxCount);
        uint256 selectedPlayersCount = 0;

        // Iterate over the players mapping and select eligible players
        address currentNode = nodes[head].next;
        while (currentNode != address(0) && selectedPlayersCount < maxCount) {
            if (eligiblePlayers[currentNode]) {
                selectedPlayers[selectedPlayersCount++] = currentNode;
            }
            currentNode = nodes[currentNode].next;
        }

        // Set the number of random players you want to select
        uint256 randomPlayersCount = 10;

        if (selectedPlayersCount < randomPlayersCount) {
            randomPlayersCount = selectedPlayersCount;
        }

        address[] memory randomPlayers = new address[](randomPlayersCount);

        for (uint256 i = 0; i < randomPlayersCount; i++) {
            if (selectedPlayersCount > 1) {
                uint256 randomIndex = uint256(
                    keccak256(
                        abi.encodePacked(
                            block.timestamp + i,
                            selectedPlayersCount,
                            currentNode
                        )
                    )
                ) % selectedPlayersCount;

                randomPlayers[i] = selectedPlayers[randomIndex];

                // Swap the selected player with the last element and decrease the count
                selectedPlayers[randomIndex] = selectedPlayers[
                    selectedPlayersCount - 1
                ];
                selectedPlayersCount--;
            } else {
                // When there's only one eligible player left, add it directly
                randomPlayers[i] = selectedPlayers[0];
                break;
            }
        }

        return randomPlayers;
    }
}

               /*********************************************************
                  Proudly Developed by MetaIdentity ltd. Copyright 2023
               **********************************************************/
