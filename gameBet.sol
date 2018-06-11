pragma solidity ^0.4.24;

contract GameBet {

    struct BetTeamInfo {
        string name;
        uint8 bets;
        uint256 totalBalance;
    }

    struct GameInfo {
        BetTeamInfo team1;
        BetTeamInfo team2;
        uint8 startsAt;
        uint256 managerCommissionPercentage;
    }
    
    address public manager;
    
    GameInfo public gameInfo;
    
    bool ended;
    
    mapping (address => uint256) public team1BetsByPlayer;
    address[] team1Bet;
    
    mapping (address => uint256) public team2BetsByPlayer;
    address[] team2Bet;
    
    constructor(string team1name, string team2name, uint8 startsAt, uint256 commission) public {
        manager = msg.sender;
        gameInfo = GameInfo(BetTeamInfo(team1name, 0, 0), BetTeamInfo(team2name, 0, 0) , startsAt, commission);
    }
    
    function enterBet(string teamName) public payable {
        require(now < gameInfo.startsAt); // This can be tricky to test, please use a big timestamp or comment this line
        require(!ended);
        require(msg.value > .001 ether);
        require(StringUtils.equal(gameInfo.team1.name, teamName) || StringUtils.equal(gameInfo.team2.name,teamName));
        
        if(StringUtils.equal(gameInfo.team1.name, teamName)) {
            if(team1BetsByPlayer[msg.sender] == 0) {
                team1Bet.push(msg.sender);
            }
            team1BetsByPlayer[msg.sender] = team1BetsByPlayer[msg.sender] + msg.value;
            gameInfo.team1.bets = gameInfo.team1.bets + 1;
            gameInfo.team1.totalBalance = gameInfo.team1.totalBalance + msg.value;
        } else {
            if(team2BetsByPlayer[msg.sender] == 0) {
                team2Bet.push(msg.sender);
            }
            team2BetsByPlayer[msg.sender] = team2BetsByPlayer[msg.sender] + msg.value;
            gameInfo.team2.bets = gameInfo.team2.bets + 1;
            gameInfo.team2.totalBalance = gameInfo.team2.totalBalance + msg.value;
        }
    }
    
    function betCountTeam1() public view returns (uint8) {
        return gameInfo.team1.bets;
    }
    
    function betCountTeam2() public view returns (uint8) {
        return gameInfo.team2.bets;
    }
    
    function betTotalTeam1() public view returns (uint256) {
        return gameInfo.team1.totalBalance;
    }
    
    function betTotalTeam2() public view returns (uint256) {
        return gameInfo.team2.totalBalance;
    }
    
    function funds() public view returns (uint256) {
        return address(this).balance;
    }
    
    function checkMyBetForTeam1() public view returns (uint256) {
        return team1BetsByPlayer[msg.sender];
    }

    function checkMyBetForTeam2() public view returns (uint256) {
        return team2BetsByPlayer[msg.sender];
    }
    
    function currentCommission() public view returns (uint256) {
        return gameInfo.managerCommissionPercentage;
    }
    
    function endGame(string winner) public {
        require(msg.sender == manager);
        require(StringUtils.equal(gameInfo.team1.name, winner) || StringUtils.equal(gameInfo.team2.name, winner));
        
        if(StringUtils.equal(gameInfo.team1.name, winner)) {
            uint256 commissionBal = (gameInfo.team2.totalBalance * gameInfo.managerCommissionPercentage) / 100;
            gameInfo.managerCommissionPercentage = 0;
            manager.transfer(commissionBal);
            
            uint256 totalForWinners = gameInfo.team2.totalBalance - commissionBal;
            
            for (uint i=0; i<team1Bet.length; i++) {
                uint256 totalBetForI = team1BetsByPlayer[team1Bet[i]];
                uint256 percentageForI = (totalBetForI * 100) / gameInfo.team1.totalBalance;
                uint256 transf = (totalForWinners * percentageForI) / 100;
                team1BetsByPlayer[team1Bet[i]] = 0;
                team1Bet[i].transfer(transf + totalBetForI);
                totalForWinners = totalForWinners - transf;
            }
        } else {
            uint256 commissionBal2 = (gameInfo.team1.totalBalance * gameInfo.managerCommissionPercentage) / 100;
            gameInfo.managerCommissionPercentage = 0;
            manager.transfer(commissionBal2);
            
            uint256 totalForWinners2 = gameInfo.team1.totalBalance - commissionBal2;
            
            for (uint j=0; j<team2Bet.length; j++) {
                uint256 totalBetForI2 = team2BetsByPlayer[team2Bet[j]];
                uint256 percentageForI2 = (totalBetForI2 * 100) / gameInfo.team2.totalBalance;
                uint256 transf2 = (totalForWinners2 * percentageForI2) / 100;
                team2BetsByPlayer[team2Bet[j]] = 0;
                team2Bet[j].transfer(transf2 + totalBetForI2);
                totalForWinners2 = totalForWinners2 - transf2;
            }
        }
        manager.transfer(address(this).balance);
        ended = true;
    }
}

library StringUtils {
    /// @dev Does a byte-by-byte lexicographical comparison of two strings.
    /// @return a negative number if `_a` is smaller, zero if they are equal
    /// and a positive numbe if `_b` is smaller.
    function compare(string _a, string _b) returns (int) {
        bytes memory a = bytes(_a);
        bytes memory b = bytes(_b);
        uint minLength = a.length;
        if (b.length < minLength) minLength = b.length;
        //@todo unroll the loop into increments of 32 and do full 32 byte comparisons
        for (uint i = 0; i < minLength; i ++)
            if (a[i] < b[i])
                return -1;
            else if (a[i] > b[i])
                return 1;
        if (a.length < b.length)
            return -1;
        else if (a.length > b.length)
            return 1;
        else
            return 0;
    }
    /// @dev Compares two strings and returns true iff they are equal.
    function equal(string _a, string _b) returns (bool) {
        return compare(_a, _b) == 0;
    }
    /// @dev Finds the index of the first occurrence of _needle in _haystack
    function indexOf(string _haystack, string _needle) returns (int)
    {
    	bytes memory h = bytes(_haystack);
    	bytes memory n = bytes(_needle);
    	if(h.length < 1 || n.length < 1 || (n.length > h.length)) 
    		return -1;
    	else if(h.length > (2**128 -1)) // since we have to be able to return -1 (if the char isn't found or input error), this function must return an "int" type with a max length of (2^128 - 1)
    		return -1;									
    	else
    	{
    		uint subindex = 0;
    		for (uint i = 0; i < h.length; i ++)
    		{
    			if (h[i] == n[0]) // found the first char of b
    			{
    				subindex = 1;
    				while(subindex < n.length && (i + subindex) < h.length && h[i + subindex] == n[subindex]) // search until the chars don't match or until we reach the end of a or b
    				{
    					subindex++;
    				}	
    				if(subindex == n.length)
    					return int(i);
    			}
    		}
    		return -1;
    	}	
    }
}
