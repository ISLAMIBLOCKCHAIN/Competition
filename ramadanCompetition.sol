// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

contract ramadanCompetition {

    address public admin = 0xB495EfB6d04400342919d0D2c0E6C120Ad814500;

    struct Player {
        uint256 score;
        bool exists;
        uint256 index;
        uint256 lastSubmission;
        uint256 daysPlayed;
    }

    mapping(address => Player) public players;

    address[] public topPlayers;
    address[] public twentyFourDays;
    uint256 public maxTopPlayers = 10;
    uint256 public numPlayers;

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
            player.index = topPlayers.length;
            topPlayers.push(_player);
            numPlayers++;
            if (topPlayers.length > maxTopPlayers) {
                removeLowestScore();
            }
        }
        
        require(!isScoreSubmittedToday(_player), "Can't update score before next day");

        player.lastSubmission = block.timestamp;
        player.score += score;
        player.daysPlayed++;

        // Sort topPlayers in descending order based on the players' scores
        for (
            uint256 i = topPlayers.length - 1;
            i > 0 &&
                players[topPlayers[i]].score > players[topPlayers[i - 1]].score;
            i--
        ) {
            address temp = topPlayers[i];
            topPlayers[i] = topPlayers[i - 1];
            topPlayers[i - 1] = temp;
            players[topPlayers[i]].index = i;
            players[topPlayers[i - 1]].index = i - 1;
        }
        emit ScoreUpdated(_player, score, player.lastSubmission);

        // Check if player's score is higher than the lowest score in topPlayers
        if (
            numPlayers > maxTopPlayers &&
            player.score > players[topPlayers[maxTopPlayers - 1]].score &&
            !isInArray(_player, topPlayers)
        ) {
            // Remove the player currently in last position
            address lastPlayer = topPlayers[topPlayers.length - 1];
            topPlayers.pop();

            // Add the new player to topPlayers
            topPlayers.push(_player);
            player.index = topPlayers.length - 1;

            // Sort topPlayers in descending order based on the players' scores
            for (
                uint256 i = topPlayers.length - 1;
                i > 0 &&
                    players[topPlayers[i]].score >
                    players[topPlayers[i - 1]].score;
                i--
            ) {
                address temp = topPlayers[i];
                topPlayers[i] = topPlayers[i - 1];
                topPlayers[i - 1] = temp;
                players[topPlayers[i]].index = i;
                players[topPlayers[i - 1]].index = i - 1;
            }

            // Emit event to notify that the player's score has been updated and they are now in topPlayers
            emit PlayerAddedToTopPlayers(
                _player,
                players[_player].score,
                player.lastSubmission
            );

            // Emit event to notify that the player previously in last position in topPlayers has been removed
            emit PlayerRemovedFromTopPlayers(
                lastPlayer,
                players[lastPlayer].score
            );

            // Check if the player was in twentyFourDays and remove them
            if (isInArray(_player, twentyFourDays)) {
                for (uint256 i = 0; i < twentyFourDays.length; i++) {
                    if (twentyFourDays[i] == _player) {
                        _player = twentyFourDays[twentyFourDays.length - 1];
                        twentyFourDays.pop();
                        break;
                    }
                }
            }

            // Check if the player removed from topPlayers can be added to twentyFourDays
            if (
                players[lastPlayer].daysPlayed >= 24 &&
                !isInArray(lastPlayer, twentyFourDays)
            ) {
                twentyFourDays.push(lastPlayer);
            }
        }

        // If player has played for 24 days and is not already in topPlayers or twentyFourDays, add them to twentyFourDays
        if (
            player.daysPlayed >= 24 &&
            player.index >= maxTopPlayers &&
            !isInArray(_player, twentyFourDays)
        ) {
            twentyFourDays.push(_player);
        }
        // Sort topPlayers in descending order based on the players' scores
            for (
                uint256 i = topPlayers.length - 1;
                i > 0 &&
                    players[topPlayers[i]].score >
                    players[topPlayers[i - 1]].score;
                i--
            ) {
                address temp = topPlayers[i];
                topPlayers[i] = topPlayers[i - 1];
                topPlayers[i - 1] = temp;
                players[topPlayers[i]].index = i;
                players[topPlayers[i - 1]].index = i - 1;
            }
    }

    function isInArray(address _player, address[] storage arr)
        internal
        view
        returns (bool)
    {
        for (uint256 i = 0; i < arr.length; i++) {
            if (_player == arr[i]) {
                return true;
            }
        }
        return false;
    }

    function removeLowestScore() internal {
        uint256 lowestScore = players[topPlayers[0]].score;
        uint256 lowestIndex = 0;

        for (uint256 i = 1; i < topPlayers.length; i++) {
            if (players[topPlayers[i]].score < lowestScore) {
                lowestScore = players[topPlayers[i]].score;
                lowestIndex = i;
            }
        }

        // Move the last player in the list to the lowest player's position
        address lastPlayer = topPlayers[topPlayers.length - 1];
        players[lastPlayer].index = lowestIndex;
        topPlayers[lowestIndex] = lastPlayer;

        // Remove the lowest player from the list
        topPlayers.pop();
    }

    function getTopPlayers()
        public
        view
        returns (address[] memory, uint256[] memory)
    {
        uint256 _numPlayers = topPlayers.length;
        address[] memory playerList = new address[](_numPlayers);
        uint256[] memory scoreList = new uint256[](_numPlayers);
        for (uint256 i = 0; i < _numPlayers; i++) {
            address playerAddress = topPlayers[i];
            playerList[i] = playerAddress;
            scoreList[i] = players[playerAddress].score;
        }
        return (playerList, scoreList);
    }

    function getRandomUsers() public view returns (address[] memory) {
        // create a list of players who played more than 24 days and not in top players
        address[] memory eligiblePlayers = new address[](twentyFourDays.length);

        uint256 numEligiblePlayers = 0;

        for (uint256 i = 0; i < twentyFourDays.length; i++) {
            address playerAddress = twentyFourDays[i];
            eligiblePlayers[i] = playerAddress;
            numEligiblePlayers++;
        }

        // if less than 10 eligible players, return all of them
        if (numEligiblePlayers <= 10) {
            return eligiblePlayers;
        }

        // shuffle the eligible players list using Fisher-Yates algorithm
        for (uint256 i = numEligiblePlayers - 1; i > 0; i--) {
            uint256 j = uint256(
                keccak256(abi.encodePacked(block.timestamp, i))
            ) % (i + 1);
            address temp = eligiblePlayers[i];
            eligiblePlayers[i] = eligiblePlayers[j];
            eligiblePlayers[j] = temp;
        }

        // select the first 10 players from the shuffled list
        address[] memory selectedPlayers = new address[](10);
        for (uint256 i = 0; i < 10; i++) {
            selectedPlayers[i] = eligiblePlayers[i];
        }

        return selectedPlayers;
    }
}

               /*********************************************************
                  Proudly Developed by MetaIdentity ltd. Copyright 2023
               **********************************************************/
