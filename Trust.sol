pragma solidity ^0.4.22;


contract Trust {
  using SafeMath for uint256;

  event Played(address playerAddress, bool isOtherPlayerCheated, bool myMove, int score);
  event Bought(address playerAddress);

  /*** DATATYPES ***/
  struct Player
  {
  	address playerAddress;
  	int seasonScore;
  	uint256 playedCount;
  	uint256 freeGameCount;
  	int currentGameScore;
    int lastGameScore;
  	uint currentStage;
  	uint currentRound;
  	uint[] otherPlayerTypeEachStage;
    uint[] otherPlayerTypeEachStageHistory;
  	bool[] stageHistory;
  	bool isPaid;
    uint256 lastPlayedTs;
    // uint256 coorpTimes;
  }

  struct SeasonGame {
  	uint256 startTime;
  	uint256 period;
  }
  
  address private ownerAddress;
  SeasonGame private currentGame;
  Player[10] public topTenOrdered;
  mapping (address => Player) public players;
  address[] public userList;
  bool private autoNewSeason;
  // uint private seasonIndex;
  uint256 private pricePerRound;
  uint private stageSize;
  uint[3] private roundSizeEachStage;


  /*** ACCESS MODIFIERS ***/
  /// @dev Access modifier for owner-only functionality
  modifier onlyOwner() {
    require(msg.sender == ownerAddress);
    _;
  }

   /*** CONSTRUCTOR ***/
  constructor () public{
  	ownerAddress = address(msg.sender);
  	autoNewSeason = false;
  	pricePerRound = 88 trx;
  	stageSize = 3;
  	roundSizeEachStage[0] = 5;
  	roundSizeEachStage[1] = 6;
  	roundSizeEachStage[2] = 7;
    _createSeasonGame(now, 259200);
  }

    /// For creating new season game
  function _createSeasonGame (uint256 startTime,
    uint256 period) private onlyOwner
  {
    SeasonGame memory _seasonGame = SeasonGame({
      startTime: startTime,
      period: period
    });
    _refreshPlayerScore();
    currentGame = _seasonGame;
  }

  // 0-no game,1-not start yet, 2-game started, 3-game ended
  function _checkSeasonGameStatus () private returns(uint status) {
  	if(currentGame.startTime == 0)
  		return 0;
  	if(now < currentGame.startTime)
  		return 1;
  	if(now < currentGame.startTime + currentGame.period)
  		return 2;
  	_endSeasonGame();
  	return 3;
  }

  function _refreshPlayerScore() private {
  	for(uint i = 0; i < userList.length; i++) {
  		players[userList[i]].seasonScore = 0;
  		players[userList[i]].currentGameScore = 0;
    }
  }
  

  function _refreshTopXOrdered(Player player) private {
    require (player.playerAddress!=0x0);
    uint i = 0;    
    /** get the index of the current max element **/
    for(i; i < topTenOrdered.length; i++) {
    	if(topTenOrdered[i].playerAddress == player.playerAddress) {
    		return;
    	}
      if(topTenOrdered[i].playerAddress==0x0 || topTenOrdered[i].seasonScore < player.seasonScore) {
          break;
      }
    }
    /** shift the array of one position (getting rid of the last element) **/
    uint offset = 0;
    for(uint j = topTenOrdered.length - 1; j > i; j--) {
     if(topTenOrdered[i].playerAddress==0x0) {
          break;
      }
    	if(topTenOrdered[j - 1].playerAddress == player.playerAddress) {
    		offset = 1;
    	}
        topTenOrdered[j] = topTenOrdered[j + offset - 1];
    }
    /** update the new max element **/
    topTenOrdered[i] =  player;
  }

  function endSeasonGame () public onlyOwner () {
    _endSeasonGame();
  }

  function getTopTen () public view returns (address[],int[],uint256[]) {
    address[] memory addrs = new address[](topTenOrdered.length);
    int[]    memory scores = new int[](topTenOrdered.length);
    uint256[]    memory lastPlays = new uint[](topTenOrdered.length);

    for (uint i=0; i < topTenOrdered.length; i++) {
      Player storage player = topTenOrdered[i];
      addrs[i] = player.playerAddress;
      scores[i] = player.seasonScore;
      lastPlays[i] = player.lastPlayedTs;
    }
    return (addrs, scores, lastPlays);
  }

  function getMyScoreAndRank () public view returns (int, uint, address) {
    uint rank = 1;
    Player memory player = players[address(msg.sender)];

    require (player.playerAddress != 0x0);
    
    int myScore = player.seasonScore;
    for (uint i=0; i < userList.length; i++) {
       int score = players[userList[i]].seasonScore;
       if (myScore<score) {
        rank++;
       }
    }

    return (myScore, rank, address(msg.sender));
  }
  
  function _endSeasonGame () private {
  	  uint256 totalAmount = address(this).balance;
  	  uint256 topTenAward = totalAmount.mul(85).div(100);
  	  uint256 developerShare = totalAmount.mul(5).div(100);
  	  uint256 top1 = topTenAward.mul(4).div(10);
  	  uint256 top2 = topTenAward.div(5);
  	  uint256 top3 = topTenAward.div(10);
  	  uint256 top4to10 = topTenAward.div(50);

  	  ownerAddress.transfer(developerShare);
  	  // distribute top 10 award
  	  for (uint i=0; i<topTenOrdered.length; i++) {
  	  	if (topTenOrdered[i].playerAddress==0x0) {
  	  		break;
  	  	}
  	  	if(i==0) {
  	  		topTenOrdered[i].playerAddress.transfer(top1);
  	  	} else if (i==1) {
  	  		topTenOrdered[i].playerAddress.transfer(top2);
  	  	} else if (i==2) {
  	  		topTenOrdered[i].playerAddress.transfer(top3);
  	  	} else {
  	  		topTenOrdered[i].playerAddress.transfer(top4to10);
  	  	}
  	  }

  	  if (autoNewSeason) {
  	  	_createSeasonGame(currentGame.startTime+currentGame.period, currentGame.period);
  	  }
  }

  function switchAutoNewSeason () public onlyOwner {
  	autoNewSeason = !autoNewSeason;
  }
  
  function updateSeasonTime (uint256 startTime, uint256 period) public onlyOwner {
  	// require (currentGame.startTime != 0);
  	currentGame.startTime = startTime;
  	currentGame.period = period;
  }

  function getSeasonGameTime () public view returns(uint256, uint256) {
  	// require (currentGame.startTime != 0);
  	return (currentGame.startTime, currentGame.period);
  }

  function getPlayerStatus () public view  returns(int seasonScore, int currentGameScore, uint256 currentStage, uint256 currentRound, 
    bool isNewPlayer, bool isPaid, uint[] pHist) {
  	Player memory player = players[address(msg.sender)];
  	if (player.playerAddress == 0x0) {
  		return (0,0,0,0,true,false,new uint256[](3));
  	}
  	return (player.seasonScore, player.currentGameScore, player.currentStage, player.currentRound, false, player.isPaid,
      player.otherPlayerTypeEachStage);
  }
  

  function payForGame () public payable {
  	Player memory player = players[address(msg.sender)];
  	require (msg.value >= pricePerRound, "no enough trx");
  
  	if (player.playerAddress == 0x0) {
  		player = _createPlayer(address(msg.sender), true);
  	} else {
      player.isPaid = true;
    }
    for(uint i=0; i < stageSize; i++) {
      player.otherPlayerTypeEachStage[i] = random(5);
    } 
    players[address(msg.sender)] = player;
    emit Bought(msg.sender);
  }

  function playARound (bool isCheated) public returns(int,bool){
  	Player memory player = players[address(msg.sender)];
  	require(player.isPaid, 'You need pay the game first');
    int score = 0;
    bool isOtherPlayerCheated =  true;
  	(score, isOtherPlayerCheated) =  _playThisRound(player, isCheated);
    emit Played(msg.sender, isOtherPlayerCheated, isCheated, score);
  	return (score, isOtherPlayerCheated);
  }
  

  function _playThisRound(Player memory player, bool isCheated) private returns(int,bool) {
  	uint currentStage = player.currentStage;
  	uint currentRound = player.currentRound;
  	uint roundSize = roundSizeEachStage[currentStage];
  	uint otherPlayerType = player.otherPlayerTypeEachStage[currentStage];
  	int score =1;
  	bool isOtherPlayerCheated=true;
  	// 0 copycat, 1 cheater, 2 cooperator, 3 grudger, 4 detective, 5 copykitten, 6 simpleton, 7 random

  	if (otherPlayerType == 0) {
      if (currentRound==0) {
        isOtherPlayerCheated = false;
      } else {
  		  isOtherPlayerCheated = player.stageHistory[currentRound-1];
      }
  	} else if (otherPlayerType == 1) {
  		isOtherPlayerCheated = true;
  	} else if (otherPlayerType == 2) {
  		isOtherPlayerCheated = false;
  	} else if (otherPlayerType == 3 || otherPlayerType == 4) {
  		bool hasCheated = _hasCheated(player.stageHistory, currentRound);
  		if (hasCheated) {
  			if (otherPlayerType == 3) {
  				isOtherPlayerCheated = true;
  				if (currentRound == 0) {
  					isOtherPlayerCheated = false;
  				}
  			} else {
  				if (currentRound > 3) {
            if (currentRound==0) {
              isOtherPlayerCheated = false;
            } else {
              isOtherPlayerCheated = player.stageHistory[currentRound-1];
            }
  				} else if (currentStage == 0) {
  					isOtherPlayerCheated = false;
  				} else if (currentStage == 1) {
  					isOtherPlayerCheated = true;
  				} else if (currentStage == 2) {
  					isOtherPlayerCheated = false;
  				} else if (currentStage == 3) {
  					isOtherPlayerCheated = false;
  				}
  			}
  		} else {
  			if (otherPlayerType == 3) {
  				isOtherPlayerCheated = false;
  			} else {
  				if (currentRound > 3) {
  					isOtherPlayerCheated = true;
  				} else if (currentStage == 0) {
  					isOtherPlayerCheated = false;
  				} else if (currentStage == 1) {
  					isOtherPlayerCheated = true;
  				} else if (currentStage == 2) {
  					isOtherPlayerCheated = false;
  				} else if (currentStage == 3) {
  					isOtherPlayerCheated = false;
  				}
  			}
  		}
  	}
  	score = _getPoint(isCheated,isOtherPlayerCheated);
    player.currentGameScore = score + player.currentGameScore;
  	// reset stage or round
    player.stageHistory[currentRound]=isCheated;
    currentRound = currentRound + 1;
  	if (roundSize <= currentRound) {
      currentStage = currentStage + 1;
  		if (stageSize <= currentStage) {
  			currentStage = 0;
  			player.seasonScore = player.seasonScore + player.currentGameScore;
        player.lastGameScore = player.currentGameScore;
  			player.currentGameScore = 0;
  			player.isPaid = false;
        _refreshTopXOrdered(player);
  		}
  		currentRound = 0;
  	}
    player.currentStage = currentStage;
    player.currentRound = currentRound;
    players[address(msg.sender)] = player;
  	return (score,isOtherPlayerCheated);
  }

 //  function _initOtherPlayer (Player player) private {
 //  player.otherPlayerTypeEachStage = player.otherPlayerTypeEachStage;
	// // delete player.otherPlayerTypeEachStage;
	// // uint[] memory types = new uint[](10);

 //  // uint16[3] memory randomTypes = random3();
 //  // types[0] = randomTypes[0];
 //  // types[1] = randomTypes[1];
 //  // types[2] = randomTypes[2];
 //  	for(uint i=0; i < stageSize; i++) {
 //  		player.otherPlayerTypeEachStage[i] = random()%5 + i;
 //  	} 
 //  	// player.otherPlayerTypeEachStage = types;
 //  }
  

  function _hasCheated (bool[] stageHistory, uint currentRound) pure private returns(bool res) {
  	for (uint i=0; i < currentRound; i++) {
  		if (stageHistory[i]) {
  			return true;
  		}
  	}
  	return false;
  }
  

  function _getPoint (bool isCheated1, bool isCheated2) pure private returns(int res) {
  	if (isCheated1 == true && isCheated2 == true) {
  		return 0;
  	} else if (isCheated1 == true && isCheated2 == false) {
  		return 3;
  	} else if (isCheated1 == false && isCheated2 == true) {
  		return -1;
  	} else {
  		return 2;
  	}
  }
  
  function _createPlayer(address newAddress, bool isPaid) private returns(Player) {
  	// uint[10] memory types = new uint[](0);
  	// bool[10] memory histories = new bool[](0);
  	Player memory _player = Player({
      playerAddress: newAddress,
      seasonScore: 0,
      playedCount: 0,
      freeGameCount: 0,
      currentStage: 0,
      currentRound: 0,
      currentGameScore: 0,
      otherPlayerTypeEachStage:new uint[](3),
      otherPlayerTypeEachStageHistory:new uint[](3),
      stageHistory: new bool[](10),
      isPaid: isPaid,
      lastPlayedTs: now,
      // coorpTimes: 0,
      lastGameScore:0
    });

    players[newAddress] = _player;
    userList.push(newAddress);
    // Player memory invitingPlayer = players[invitingAddress];
    // if (invitingPlayer.playerAddress != 0x0) {
    // 	invitingPlayer.freeGameCount = invitingPlayer.freeGameCount+1;
    // }

    return _player;
  }

  uint private nonce = 0;
  function random(uint size) private returns(uint) {
        nonce += 1;
        return uint(keccak256(abi.encodePacked(nonce, msg.sender, blockhash(block.number - 1))))% size;
  }
}



library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  /**
  * @dev Substracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}
