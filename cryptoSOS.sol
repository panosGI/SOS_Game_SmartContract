// SPDX-License-Identifier: AUEB
pragma solidity 0.8;

contract CryptoSOS {

    // Game state enumeration
    enum State { WaitingForSecondPlayer, Ongoing, Finished }
    State public gameState;

    address public player1;
    address public player2;
    address public owner;
    uint256 public lastMoveTime;
    uint256 public moveTimeout = 1 minutes;
    uint256 public gameTimeout = 5 minutes;
    uint256 public depositAmount = 1 ether;
    uint256 public winnerPrize = 1.8 ether;
    uint256 public tieRefund = 0.95 ether;




    // Game board, indexed 1 to 9 for easy mapping
    uint8[9] public board;

    uint8 public turn; 
    bool public player1Joined;
    bool public player2Joined;

    // Events
    event StartGame(address player1, address player2);
    event Move(address player, uint8 position, char letter);
    event Winner(address winner);
    event Tie(address player1, address player2);
   
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier gameInProgress() {
        require(gameState == State.Ongoing, "No game in progress");
        _;
    } 

    modifier isPlayer() {
        require(msg.sender == player1 || msg.sender == player2, "Not a player");
        _;
    }


    modifier onlyIfNotJoined() {
        require(!player1Joined || !player2Joined, "Game already started");
        _;
    }
    modifier playerTurn() {
        require((msg.sender == player1 && turn == 1) || (msg.sender == player2 && turn == 2), "Not your turn");
        _;
    }

modifier validPosition(uint8 position) {
        require(position >= 1 && position <= 9, "Invalid position");
        require(board[position - 1] == 0, "Square already taken");
    }

modifier timeoutPassed(address msg.sender) {
    if (msg.sender == player1 || msg.sender == player2) {
        require(block.timestamp - lastMoveTime > moveTimeout, "Player hasn't timed out yet");
        require(turn != (player == player1 ? 1 : 2), "It's your turn, not the opponent's");
    } else if (msg.sender == owner) {
        require(block.timestamp - lastMoveTime > gameTimeout, "Game hasn't timed out yet");
    }
    _;
}

    constructor() {
        owner = msg.sender;
        gameState = State.WaitingForSecondPlayer;
    }

    // Function for a player to join
    function join() external payable onlyIfNotJoined {
        require(msg.value == depositAmount, "Incorrect deposit amount");
        
        if (!player1Joined) {
            player1 = msg.sender;
            player1Joined = true;
            emit StartGame(player1, address(0)); // First player joins
        } else if (!player2Joined) {
            player2 = msg.sender;
            player2Joined = true;
            gameState = State.Ongoing;
            lastMoveTime = block.timestamp;
            turn = 1; // Player 1 starts
            emit StartGame(player1, player2); // Second player joins
        } else {
            revert("Game already in progress");
        }
    }

    // Function to place 'S'
    function placeS(uint8 position) external gameInProgress isPlayer playerTurn validPosition(position) {
        board[position - 1] = 1; //"S"
        emit Move(msg.sender, position, 1);
        checkGameState();
        if(msg.sender==player1){
            turn = 2;
            if(isWinner(player1)){emit Winner(player1)}; //check if u win
         }
        else{
            turn=1;
            if(isWinner(player2)){emit Winner(player2)};  //check if u win
        }        
        lastMoveTime = block.timestamp;
    }
      function placeO(uint8 position) external gameInProgress isPlayer playerTurn validPosition(position) {
        board[position - 1] = 2; //"O"
        emit Move(msg.sender, position, 2);
        checkGameState();
        if(msg.sender==player1){turn = 2;}
        else{turn=1;}        
        lastMoveTime = block.timestamp;
    }

    // Check game status (winner/tie)
    function checkGameState() private {
        if (isWinner(player1)) {
            gameState = State.Finished;
            emit Winner(player1);
            payable(player1).transfer(winnerPrize);
        } else if (isWinner(player2)) {
            gameState = State.Finished;
            emit Winner(player2);
            payable(player2).transfer(winnerPrize);
        } else if (isBoardFull()) {
            gameState = State.Finished;
            emit Tie(player1, player2);
            payable(player1).transfer(tieRefund);
            payable(player2).transfer(tieRefund);
        }
    }

  
 
    // Check if a player has won by forming "SOS"
    function isWinner(address player) private view returns (bool) {
        // Check if they have formed "SOS"
        return (checkForSOS());
    }
  
    // Function to check if 'SOS' is formed anywhere on the board
    function checkForSOS() internal view returns (bool) {

            //save gas > Readability!

    // Check for "SOS" in rows, columns, and diagonals
    if (
        checkSquares(0, 1, 2) || checkSquares(3, 4, 5) || checkSquares(6, 7, 8) ||  // Rows
        checkSquares(0, 3, 6) || checkSquares(1, 4, 7) || checkSquares(2, 5, 8) ||  // Columns
        checkSquares(0, 4, 8) || checkSquares(2, 4, 6)                             // Diagonals
    ) {
        return true;
    }

        return false;
    }

    // Function to check if "SOS" exists in a specific row
    function checkSquares(uint8 a, uint8 b, uint8 c) internal view returns (bool) {
        return (
            board[a] == 1 && board[b] == 2 && board[c] == 1
        );
    }

    // Check if the board is full
    function isBoardFull() private view returns (bool) {
        for (uint8 i = 0; i < 9; i++) {
            if (board[i] == 0) return false;
        }
        return true;
    }


    function tooslow() external timeoutPassed(msg.sender) { 
     //exoume exasfalisei oti h tooslow kaleitai swsta apo thn timeoutpassed
    address winner;
    if (msg.sender == player1) { 
         gameState = State.Finished;
         winner = player1; // Player 2 timed out, player 1 wins 
        emit Winner(winner);
        payable(winner).transfer(winnerPrize);
     }
    else if (msg.sender == player2) { 
         gameState = State.Finished;
         winner = player2; // Player 1 timed out, player 2 wins 
         emit Winner(winner);
         payable(winner).transfer(winnerPrize);
    }
    else if (msg.sender == owner) { winner = address(0); // Tie if the owner calls it 
         gameState = State.Finished;
        emit Tie(player1, player2);
         // Refund both players in case of a tie
        payable(player1).transfer(tieRefund);
        payable(player2).transfer(tieRefund);    
    }
    }
    // Get the current game state (board)
    function getGameState() external view returns (string memory) {
    // Initialize an empty string
    bytes memory boardString = new bytes(9);

    // Convert each uint8 to the corresponding string character and store it in boardString
    for (uint8 i = 0; i < 9; i++) {
        if (board[i] == 1) {
            boardString[i] = 'S'; // 1 corresponds to 'S'
        } else if (board[i] == 2) {
            boardString[i] = 'O'; // 2 corresponds to 'O'
        } else {
            boardString[i] = '-'; // 0 corresponds to an empty space
        }
    }
        // Return the board as a string
         return string(boardString);
    }


    function sweepProfit(uint amount) external onlyOwner {
	
	if(gameState.isOngoing()){
		require(address(this).balance-amount >= 1.9,”must leave balance for prizes”)
        }
    else If(gameState.isWaitingForPlayer2()){
	    require(address(this).balance-amount >= 1,”must leave players deposit”)
    }
    else{ 				//finished
	        require(address(this).balance >= amount, "Insufficient balance");
    } 
        payable(owner).transfer(amount);
    }	
}