// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract StakeEther {

    address owner;
    uint256 daysInYear;
    uint256 public unlockTime;


    constructor () {
        owner = msg.sender;
        daysInYear = 365;
        unlockTime = block.timestamp + 10 days;
    }

    struct stakingPlan {
        string planName;
        uint256 duration; //Duration in in days
        uint256 interestRate;
        uint8 planId;
        bool exists;
    }

    struct userStake {
        uint8 planId;
        uint256 endTime;
        uint256 amountStaked;
        uint256 estimatedInterest;
        uint256 created_at;
        bool isEnded;
        bool isWithdrawn;
    }
    // mapping staking plan ID to plans
    mapping(uint8 => stakingPlan) plans;
    //User Balances Mapping
    mapping(address => uint256) totalAmountStakedBalances;
    mapping(address => uint256) rewardBalances;
    mapping(address => uint256) totalAmountRewardedBalances;
    //Map a plan to user
    // mapping (address => userStake[]) stakesByAddess;

    mapping (address => mapping (uint8 => userStake[])) stakesByUser;
    //Implement 2D Mapping

    
    stakingPlan [] allPlans;

    event createPlanSuccessful(string nameOfPlan, uint256 _duration, uint256 interestRate, uint8 planId);
    event depositSuccessful(uint _amount, address _address, string planNmae);

    //Function to create staking plans
    function createPlan(string memory _nameOfPlan, uint256 _duration, uint256 _interestRate, uint8 _planId) external onlyOwner  {
        //check if planId already exists.
        bytes memory nameInByte = bytes(_nameOfPlan);
        require(!plans[_planId].exists, "Plan ID already Exists");
        require(keccak256(abi.encodePacked(plans[_planId].planName)) != keccak256(abi.encodePacked(nameInByte)) , "Plan Name already Exists.");
        stakingPlan memory sp;
        sp.planName = _nameOfPlan;
        sp.interestRate = _interestRate;
        sp.planId = _planId;
        sp.duration = _duration;
        sp.exists = true;
        allPlans.push(sp);
        plans[_planId] = sp;
        emit createPlanSuccessful(_nameOfPlan, _duration, _interestRate, _planId);
    }

    function getAllStakingPlan() external view onlyOwner returns (stakingPlan[] memory) {
        return allPlans;
    }

    //Function for user to stake to a plan in the contract
    //User choose the plan they want to stake in
    //Function is payable so we can recieve ether through this function
     function stake(uint8 _planID) external payable {
        require(msg.sender != address(0), "Sender address is a zero address");
        require(msg.value > 0, "Amount to deposit must be greater than zero.");
        require(plans[_planID].planId == _planID, "Invalid plan ID");
        //Increase staked balance;
        totalAmountStakedBalances[msg.sender] += msg.value;
        //Get the plan User wants to stake in
        stakingPlan memory selectedPlan = plans[_planID];
        uint256 interest = calculateInterest(msg.value, selectedPlan.interestRate, selectedPlan.duration);
        stakesByUser[msg.sender][_planID].push(userStake({
            planId: _planID,
            endTime: block.timestamp + (selectedPlan.duration * 24 * 60 * 60), //Convert the plan to seconds.
            created_at: block.timestamp,
            estimatedInterest: interest,
            amountStaked: msg.value,
            isEnded: false,
            isWithdrawn: false
        }));
        
        emit depositSuccessful(msg.value, msg.sender, selectedPlan.planName);
    }


     modifier onlyOwner {
        require(msg.sender == owner, "You are not the owner of this contract");
        _;
    }


}