// SPDX-License-Identifier: AUEB
pragma solidity 0.8;

contract MultiSOS {
    enum State { WaitingForFirstPlayer, WaitingForSecondPlayer, Ongoing, Finished }
    
    struct Game {
        address player1;
        address player2;
        State gameState;
        uint256 lastMoveTime;
        uint256 moveTimeout;
        uint8[9] board;
        uint8 turn;
    }

    uint256 public depositAmount = 1 ether;
    uint256 public winnerPrize = 1.8 ether;
    uint256 public tieRefund = 0.95 ether;
    uint256 public winnerPrizeTooSlow = 1.5 ether;
    uint256 public gameTimeout = 5 minutes;
    uint256 public moveTimeout = 1 minutes;
    uint256 public cancelTimeout = 2 minutes;
    address public owner;

    Game[] public games;
    mapping(address => uint256) public playerToGame;

    event StartGame(address player1, address player2);
    event Move(address player, uint8 position, string letter);
    event Winner(address winner);
    event Tie(address player1, address player2);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier validPosition(uint8 position) {
        uint256 gameId=playerToGame[msg.sender];
        require(position >= 1 && position <= 9, "Invalid position");
        require(games[gameId].board[position - 1] == 0, "Square already taken");
        _;
    }

    modifier playerTurn() {
        uint256 gameId=playerToGame[msg.sender];
        require((msg.sender == games[gameId].player1 && games[gameId].turn == 1) ||
                (msg.sender == games[gameId].player2 && games[gameId].turn == 2), "Not your turn");
        _;
    }

    modifier isPlayer() {
        bool isInGame = false;
        for (uint256 i = 0; i < games.length; i++) {
            if (games[i].player1 == msg.sender || games[i].player2 == msg.sender) {
                isInGame = true;
                break;
            }
        }
        require(isInGame, "You are not in any active game");
        _;
    }

    modifier timeoutPassed() {
        uint256 gameId=playerToGame[msg.sender];

        if (msg.sender == games[gameId].player1) {
            require(block.timestamp - games[gameId].lastMoveTime > moveTimeout, "Player hasn't timed out yet");
            require(games[gameId].turn==2, "It's your turn, not the opponent's");
        }
        else if  (msg.sender == games[gameId].player2) {
            require(block.timestamp - games[gameId].lastMoveTime > moveTimeout, "Player hasn't timed out yet");
            require(games[gameId].turn==1, "It's your turn, not the opponent's");    
        }    
        else if (msg.sender == owner) {
            require(block.timestamp - games[gameId].lastMoveTime > gameTimeout, "Game hasn't timed out yet");
        }
        _;  
    }

    constructor() {
        owner = msg.sender;
    }

    function join() external payable {
        require(msg.value == depositAmount, "Incorrect deposit amount");
        
        // Check if the player is already in a game
        uint256 gameId = playerToGame[msg.sender];//arxika einai 0 wws default ths solidity
        require(gameId == 0, "Player already in a game");

        bool gameFound = false;
        for (uint256 i = 0; i < games.length; i++) {
            if (games[i].gameState == State.WaitingForSecondPlayer) {
                games[i].player2 = msg.sender;
                games[i].gameState = State.Ongoing;
                games[i].turn = 1;
                games[i].lastMoveTime = block.timestamp;
                playerToGame[msg.sender] = i;
                emit StartGame(games[i].player1, games[i].player2);
                gameFound = true;
                break;
            }
        }

        if (!gameFound) {
            Game memory newGame = Game({
                player1: msg.sender,
                player2: address(0),
                gameState: State.WaitingForSecondPlayer,
                lastMoveTime: block.timestamp,
                moveTimeout: 1 minutes,
                board: [uint8(0), uint8(0), uint8(0), uint8(0), uint8(0), uint8(0), uint8(0), uint8(0), uint8(0)],
                turn: 0
            });
            games.push(newGame);
            playerToGame[msg.sender] = games.length - 1;
            emit StartGame(msg.sender, address(0));
        }
    }

    function placeS(uint8 position) external isPlayer playerTurn validPosition(position) {
        uint256 gameId = playerToGame[msg.sender];
        games[gameId].board[position - 1] = 1; //"S"
        emit Move(msg.sender, position, "S");

        if (isWinner(msg.sender)) {
            emit Winner(msg.sender);
            payable(msg.sender).transfer(winnerPrize);
            games[gameId].gameState = State.Finished;  // Mark game as finished if player1 wins
            clearGameData();
        }
        else if (isBoardFull(gameId)) {
            games[gameId].gameState = State.Finished;
            emit Tie(games[gameId].player1, games[gameId].player2);
            payable(games[gameId].player1).transfer(tieRefund);
            payable(games[gameId].player2).transfer(tieRefund);
            clearGameData();
        }
        else  
        games[gameId].turn = (games[gameId].turn == 1) ? 2 : 1;
        games[gameId].lastMoveTime = block.timestamp;
    }

    function placeO(uint8 position) external isPlayer playerTurn validPosition(position) {
        uint256 gameId = playerToGame[msg.sender];
        games[gameId].board[position - 1] = 2; //"O"
        emit Move(msg.sender, position, "O");

        if (isWinner(msg.sender)) {
            emit Winner(msg.sender);
            payable(msg.sender).transfer(winnerPrize);
            games[gameId].gameState = State.Finished;  // Mark game as finished if player1 wins
            clearGameData();
        }
        else if (isBoardFull(gameId)) {
            games[gameId].gameState = State.Finished;
            emit Tie(games[gameId].player1, games[gameId].player2);
            payable(games[gameId].player1).transfer(tieRefund);
            payable(games[gameId].player2).transfer(tieRefund);
            clearGameData();
        }
        else  
        games[gameId].turn = (games[gameId].turn == 1) ? 2 : 1;
        games[gameId].lastMoveTime = block.timestamp;
    }
    
    // Check if a player has won by forming "SOS"
    function isWinner(address) private view returns (bool) {
        // Check if they have formed "SOS"
        uint gameId= playerToGame[msg.sender];
        return (checkForSOS(gameId));
    }    

    function checkForSOS(uint256 gameId) private view returns (bool) {
        uint8[9] memory board = games[gameId].board;
        return (checkSquares(board, 0, 1, 2) || checkSquares(board, 3, 4, 5) || checkSquares(board, 6, 7, 8) ||
                checkSquares(board, 0, 3, 6) || checkSquares(board, 1, 4, 7) || checkSquares(board, 2, 5, 8) ||
                checkSquares(board, 0, 4, 8) || checkSquares(board, 2, 4, 6));
    }

    function checkSquares(uint8[9] memory board, uint8 a, uint8 b, uint8 c) internal pure returns (bool) {
        return (board[a] == 1 && board[b] == 2 && board[c] == 1);
    }

     // Check if the board is full
    function isBoardFull(uint256 gameId) private view returns (bool) {
        for (uint8 i = 0; i < 9; i++) {
            if (games[gameId].board[i] == 0) return false;
        }
        return true;
    }

    
    // Get the current game state (board)
    function getGameState() external view isPlayer returns (string memory) {
        uint gameId= playerToGame[msg.sender];
        // Initialize an empty string
        bytes memory boardString = new bytes(9);
        // Convert each uint8 to the corresponding string character and store it in boardString
        for (uint8 i = 0; i < 9; i++) {
            if (games[gameId].board[i] == 1) 
                boardString[i] = 'S'; // 1 corresponds to 'S'
            else if (games[gameId].board[i] == 2) 
                boardString[i] = 'O'; // 2 corresponds to 'O'
            else 
                boardString[i] = '-'; // 0 corresponds to an empty space
        }
        // Return the board as a string
         return string(boardString);
    }

    function tooslow() external isPlayer timeoutPassed{ 
        uint gameId= playerToGame[msg.sender];

        if (msg.sender == games[gameId].player1||msg.sender ==games[gameId].player2) { 
            games[gameId].gameState = State.Finished;
            emit Winner(msg.sender);
            payable(msg.sender).transfer(winnerPrizeTooSlow);
            clearGameData();
        }

        else if (msg.sender == owner) { 
            // Tie if the owner calls it 
            games[gameId].gameState = State.Finished;
            emit Tie(games[gameId].player1, games[gameId].player2);
            // Refund both players in case of a tie
            payable(games[gameId].player1).transfer(tieRefund);
            payable(games[gameId].player2).transfer(tieRefund); 
            clearGameData();   
        }
    }


    function cancel() external payable isPlayer {
        uint gameId= playerToGame[msg.sender];

        if( msg.sender==games[gameId].player1&&games[gameId].gameState==State.WaitingForSecondPlayer &&
                block.timestamp-games[gameId].lastMoveTime>cancelTimeout){
          payable(games[gameId].player1).transfer(depositAmount);
          games[gameId].gameState=State.Finished;
          clearGameData();
        }
        else revert("Cannot cancel game yet");    
    } 


    function sweepProfit(uint256 amount) external onlyOwner {
        uint256 totalRequiredAmount = 0;

        // Calculate the total required amount to ensure there is enough to pay prizes/refunds for ongoing games
        for (uint256 i = 0; i < games.length; i++) {
            if (games[i].gameState == State.Ongoing) {
                totalRequiredAmount += winnerPrize ;  // Account for potential winner payouts
            } 
            else if (games[i].gameState == State. WaitingForSecondPlayer){
                totalRequiredAmount += depositAmount;
            }        
         // den elegxw thn periptwsh state finished h witinggforfirstplayer giati diagrafetai aytomata apo ton pinaka
    
        uint256 currentBalance = address(this).balance;
        require(currentBalance - totalRequiredAmount >= amount, "Insufficient funds to sweep this amount");

        // Send the requested amount to the owner
        payable(owner).transfer(amount);
        }
    }
    
    function clearGameData() internal { 
        uint gameId= playerToGame[msg.sender];
        delete(games[gameId]);
        playerToGame[msg.sender] = 0;
    }
}
    


