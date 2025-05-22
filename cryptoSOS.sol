// SPDX-License-Identifier: AUEB
pragma solidity 0.8;

contract CryptoSOS {

    // Game state enumeration
    enum State { WaitingForFirstPlayer,WaitingForSecondPlayer, Ongoing, Finished }
    State public gameState;

    address public player1;
    address public player2;
    address public owner;
    uint256 public lastMoveTime;
    uint256 public moveTimeout = 1 minutes;
    uint256 public gameTimeout = 5 minutes;
    uint256 public cancelTimeout = 2 minutes;
    uint256 public depositAmount = 1 ether;
    uint256 public winnerPrize = 1.8 ether;
    uint256 public tieRefund = 0.95 ether;
    uint256 public winnerPrizeTooSlow= 1.5 ether;

    uint8[9] public board;
    uint8 public turn; 
    bool public player1Joined;
    bool public player2Joined;

    // Events
    event StartGame(address player1, address player2);
    event Move(address player, uint8 position, string letter);
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

    modifier onlyIfNot2Joined() {
        //require(!player1Joined || !player2Joined, "Game already started");
        require(!(gameState==State.Ongoing), "Game already started"); 
        _;
    }
    
    modifier playerTurn() {
        require((msg.sender == player1 && turn == 1) || (msg.sender == player2 && turn == 2), "Not your turn");
        _;
    }

    modifier validPosition(uint8 position) {
        require(position >= 1 && position <= 9, "Invalid position");
        require(board[position - 1] == 0, "Square already taken");
        _;
    }

    modifier timeoutPassed() {
        if (msg.sender == player1) {
            require(block.timestamp - lastMoveTime > moveTimeout, "Player hasn't timed out yet");
            require(turn==2, "It's your turn, not the opponent's");
        }
        else if  (msg.sender == player2) {
            require(block.timestamp - lastMoveTime > moveTimeout, "Player hasn't timed out yet");
            require(turn==1, "It's your turn, not the opponent's");    
        }    
        else if (msg.sender == owner) {
            require(block.timestamp - lastMoveTime > gameTimeout, "Game hasn't timed out yet");
        }
        _;  
    }

    constructor() {
        owner = msg.sender;
        gameState = State.WaitingForFirstPlayer;
        for(uint8 i=0;i<9;i++)board[i]=0;
    }

    // Function for a player to join
    function join() external payable onlyIfNot2Joined {
        require(msg.value == depositAmount, "Incorrect deposit amount");
        if (!player1Joined) {
            player1 = msg.sender;
            player1Joined = true;
            emit StartGame(player1, address(0)); // First player joins
            lastMoveTime=block.timestamp;
            gameState=State.WaitingForSecondPlayer;
        } 
        else if (player1Joined && !player2Joined) {
            require(msg.sender != player1, "You cannot play a game against yourself!");            
                {
                player2 = msg.sender;
                player2Joined = true;
                gameState = State.Ongoing;
                lastMoveTime = block.timestamp;
                turn = 1; // Player 1 starts
                emit StartGame(player1, player2); // Second player joins
                }
            }    
         
        else {
            revert("Game already in progress");
        }
    
    }

    // Function to place 'S'
    function placeS(uint8 position) external gameInProgress isPlayer playerTurn validPosition(position) {
        board[position - 1] = 1; //"S"
        emit Move(msg.sender, position, "S");
        if ((msg.sender == player1 && isWinner(player1))||(msg.sender == player2 && isWinner(player2))) {
            emit Winner(msg.sender);
            payable(msg.sender).transfer(winnerPrize);
            gameState = State.Finished;  // Mark game as finished if player1 wins
            clearGameData();
        } 
        else if (isBoardFull()) {
            gameState = State.Finished;
            emit Tie(player1, player2);
            payable(player1).transfer(tieRefund);
            payable(player2).transfer(tieRefund);
            clearGameData();
        }
        else  turn = (turn == 1) ? 2 : 1;
        lastMoveTime = block.timestamp;
    }
      
    function placeO (uint8 position) external gameInProgress isPlayer playerTurn validPosition(position) {
        board[position - 1] = 2; 
        emit Move(msg.sender, position, "O");
        if (msg.sender == player1 && isWinner(player1)) {
            emit Winner(player1);
            payable(player1).transfer(winnerPrize);
            gameState = State.Finished;  // Mark game as finished if player1 wins
            clearGameData();
        } 
        else if (msg.sender == player2 && isWinner(player2)) {
            emit Winner(player2);
            payable(player2).transfer(winnerPrize);
            gameState = State.Finished;  // Mark game as finished if player2 wins
            clearGameData();
        } 
        else if (isBoardFull()) {
            gameState = State.Finished;
            emit Tie(player1, player2);
            payable(player1).transfer(tieRefund);
            payable(player2).transfer(tieRefund);
            clearGameData();
        }
        else turn = (turn == 1) ? 2 : 1;
        // Update last move time for timeout tracking
        lastMoveTime = block.timestamp;
    }
    
    // Check if a player has won by forming "SOS"
    function isWinner(address) private view returns (bool) {
        // Check if they have formed "SOS"
        return (checkForSOS());
    }
  
    // Function to check if 'SOS' is formed anywhere on the board
    function checkForSOS() private view returns (bool) {
        // Check for "SOS" in rows, columns, and diagonals
        if (checkSquares(0, 1, 2) || checkSquares(3, 4, 5) || checkSquares(6, 7, 8) ||  // Rows
        checkSquares(0, 3, 6) || checkSquares(1, 4, 7) || checkSquares(2, 5, 8) ||  // Columns
        checkSquares(0, 4, 8) || checkSquares(2, 4, 6)                             // Diagonals
        ) return true;
        else return false;
    }

    // Function to check if "SOS" exists in a specific triple
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

    function tooslow() external timeoutPassed() { 
        //exoume exasfalisei oti h tooslow kaleitai swsta apo thn timeoutpassed
        /*address winner;
        if (msg.sender == player1) { 
            gameState = State.Finished;
            winner = player1; // Player 2 timed out, player 1 wins 
            emit Winner(winner);
            payable(winner).transfer(winnerPrizeTooSlow);
            clearGameData();
        }
        else if (msg.sender == player2) { 
            gameState = State.Finished;
            winner = player2; // Player 1 timed out, player 2 wins 
            emit Winner(winner);
            payable(winner).transfer(winnerPrizeTooSlow);
            clearGameData();
        }
        */
         if (msg.sender == player1||msg.sender ==player2) { 
            gameState = State.Finished;
            emit Winner(msg.sender);
            payable(msg.sender).transfer(winnerPrizeTooSlow);
            //clearGameData();
        }

        else if (msg.sender == owner) { 
            // Tie if the owner calls it 
            gameState = State.Finished;
            emit Tie(player1, player2);
            // Refund both players in case of a tie
            payable(player1).transfer(tieRefund);
            payable(player2).transfer(tieRefund); 
            clearGameData();   
        }
    }

    function cancel() external payable  {
        if( msg.sender==player1&&gameState==State.WaitingForSecondPlayer&&block.timestamp-lastMoveTime>cancelTimeout){
          payable(player1).transfer(depositAmount);
          gameState=State.Finished;
          clearGameData();
        }
        else revert("Cannot cancel game yet");    
    } 
    // Get the current game state (board)
    function getGameState() external view returns (string memory) {
        // Initialize an empty string
        bytes memory boardString = new bytes(9);
        // Convert each uint8 to the corresponding string character and store it in boardString
        for (uint8 i = 0; i < 9; i++) {
            if (board[i] == 1) 
                boardString[i] = 'S'; // 1 corresponds to 'S'
            else if (board[i] == 2) 
                boardString[i] = 'O'; // 2 corresponds to 'O'
            else 
                boardString[i] = '-'; // 0 corresponds to an empty space
        }
        // Return the board as a string
         return string(boardString);
    }


    function sweepProfit(uint amount) external payable onlyOwner {
	    if(gameState==State.Ongoing)
		    require(address(this).balance-amount >= 1.9 * 10**18,"must leave balance for prizes");        
        else if (gameState==State.WaitingForSecondPlayer)
	        require(address(this).balance-amount >= 1*10**18,"must leave players deposit");
        else require(address(this).balance >= amount, "Insufficient balance");//finished or waitingforfirstplayer
        payable(owner).transfer(amount);
    }
    
    function clearGameData() internal{ 
        player1Joined=false;
        player2Joined=false; 
        player1=address(0);
        player2=address(0);
        turn=0; 
        gameState= State.WaitingForFirstPlayer;
        for(uint8 i=0;i<9;i++)board[i]=0;
        lastMoveTime=block.timestamp;
    }
    
}