// SPDX-License-Identifier: AUEB
pragma solidity 0.8;

contract MultiSOS {

    // Game state enumeration
    enum State { WaitingForSecondPlayer, Ongoing, Finished }
    
    // Game struct to hold individual game data
    struct Game {
        address player1;
        address player2;
        address winner;
        uint8[9] board;
        uint8 turn; // 1 for player1's turn, 2 for player2's turn
        State gameState;
        uint256 lastMoveTime;
    }

    address public owner;
    uint256 public moveTimeout = 1 minutes;
    uint256 public gameTimeout = 5 minutes;
    uint256 public depositAmount = 1 ether;
    uint256 public winnerPrize = 1.8 ether;
    uint256 public tieRefund = 0.95 ether;
    
    mapping(address => uint256) public playerGame;
    Game[] public games;

    // Events
    event StartGame(uint256 gameId, address player1, address player2);
    event Move(uint256 gameId, address player, uint8 position, uint8 letter);
    event Winner(uint256 gameId, address winner);
    event Tie(uint256 gameId, address player1, address player2);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier isPlayer(uint256 gameId) {
        require(msg.sender == games[gameId].player1 || msg.sender == games[gameId].player2, "Not a player in this game");
        _;
    }

    modifier playerTurn(uint256 gameId) {
        require((msg.sender == games[gameId].player1 && games[gameId].turn == 1) || 
                (msg.sender == games[gameId].player2 && games[gameId].turn == 2), "Not your turn");
        _;
    }

    modifier validPosition(uint256 gameId, uint8 position) {
        require(position >= 1 && position <= 9, "Invalid position");
        require(games[gameId].board[position - 1] == 0, "Square already taken");
        _;
    }

    modifier timeoutPassed(uint256 gameId) {
        require(block.timestamp - games[gameId].lastMoveTime > moveTimeout, "Move timeout has not passed");
        _;
    }

    modifier onlyIfNotInGame() {
        require(playerGame[msg.sender] == 0, "You are already in a game");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    // Function for a player to join a game or start a new game
    function join() external payable onlyIfNotInGame {
        require(msg.value == depositAmount, "Incorrect deposit amount");

        uint256 gameId = 0;

        // Find an available game to join (waiting for second player)
        for (uint256 i = 0; i < games.length; i++) {
            if (games[i].gameState == State.WaitingForSecondPlayer) {
                gameId = i;
                break;
            }
        }

        if (gameId == 0) {
            // Start a new game if no waiting games are found
            gameId = games.length;
            games.push();
            games[gameId].gameState = State.WaitingForSecondPlayer;
        }

        Game storage game = games[gameId];

        // Assign players
        if (game.player1 == address(0)) {
            game.player1 = msg.sender;
        } else if (game.player2 == address(0)) {
            game.player2 = msg.sender;
            game.gameState = State.Ongoing;
            game.turn = 1; // Player 1 starts
            game.lastMoveTime = block.timestamp;
            emit StartGame(gameId, game.player1, game.player2);
        }

        // Record player's game participation
        playerGame[msg.sender] = gameId;
    }

    // Function to place 'S'
    function placeS(uint256 gameId, uint8 position) external isPlayer(gameId) playerTurn(gameId) validPosition(gameId, position) {
        games[gameId].board[position - 1] = 1; //"S"
        emit Move(gameId, msg.sender, position, 1);
        checkGameState(gameId);

        // Switch turns
        if (msg.sender == games[gameId].player1) {
            games[gameId].turn = 2;
            if (isWinner(gameId, games[gameId].player1)) {
                emit Winner(gameId, games[gameId].player1);
            }
        } else {
            games[gameId].turn = 1;
            if (isWinner(gameId, games[gameId].player2)) {
                emit Winner(gameId, games[gameId].player2);
            }
        }

        games[gameId].lastMoveTime = block.timestamp;
    }

    // Function to place 'O'
    function placeO(uint256 gameId, uint8 position) external isPlayer(gameId) playerTurn(gameId) validPosition(gameId, position) {
        games[gameId].board[position - 1] = 2; //"O"
        emit Move(gameId, msg.sender, position, 2);
        checkGameState(gameId);

        // Switch turns
        if (msg.sender == games[gameId].player1) {
            games[gameId].turn = 2;
        } else {
            games[gameId].turn = 1;
        }

        games[gameId].lastMoveTime = block.timestamp;
    }

    // Check game status (winner/tie)
    function checkGameState(uint256 gameId) private {
        Game storage game = games[gameId];

        if (isWinner(gameId, game.player1)) {
            game.gameState = State.Finished;
            emit Winner(gameId, game.player1);
            payable(game.player1).transfer(winnerPrize);
        } else if (isWinner(gameId, game.player2)) {
            game.gameState = State.Finished;
            emit Winner(gameId, game.player2);
            payable(game.player2).transfer(winnerPrize);
        } else if (isBoardFull(gameId)) {
            game.gameState = State.Finished;
            emit Tie(gameId, game.player1, game.player2);
            payable(game.player1).transfer(tieRefund);
            payable(game.player2).transfer(tieRefund);
        }
    }

    // Check if a player has won by forming "SOS"
    function isWinner(uint256 gameId, address player) private view returns (bool) {
        return checkForSOS(gameId);
    }

    // Function to check if 'SOS' is formed anywhere on the board
    function checkForSOS(uint256 gameId) internal view returns (bool) {
        Game storage game = games[gameId];

        if (
            checkSquares(gameId, 0, 1, 2) || checkSquares(gameId, 3, 4, 5) || checkSquares(gameId, 6, 7, 8) ||  // Rows
            checkSquares(gameId, 0, 3, 6) || checkSquares(gameId, 1, 4, 7) || checkSquares(gameId, 2, 5, 8) ||  // Columns
            checkSquares(gameId, 0, 4, 8) || checkSquares(gameId, 2, 4, 6)                             // Diagonals
        ) {
            return true;
        }

        return false;
    }

    // Function to check if "SOS" exists in a specific row
    function checkSquares(uint256 gameId, uint8 a, uint8 b, uint8 c) internal view returns (bool) {
        Game storage game = games[gameId];
        return (game.board[a] == 1 && game.board[b] == 2 && game.board[c] == 1);
    }

    // Check if the board is full
    function isBoardFull(uint256 gameId) private view returns (bool) {
        Game storage game = games[gameId];
        for (uint8 i = 0; i < 9; i++) {
            if (game.board[i] == 0) return false;
        }
        return true;
    }

    // Get the current game state (board)
    function getGameState(uint256 gameId) external view returns (string memory) {
        Game storage game = games[gameId];
        bytes memory boardString = new bytes(9);

        for (uint8 i = 0; i < 9; i++) {
            if (game.board[i] == 1) {
                boardString[i] = 'S'; // 1 corresponds to 'S'
            } else if (game.board[i] == 2) {
                boardString[i] = 'O'; // 2 corresponds to 'O'
            } else {
                boardString[i] = '-'; // 0 corresponds to an empty space
            }
        }
        return string(boardString);
    }
}
