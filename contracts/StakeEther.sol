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


     modifier onlyOwner {
        require(msg.sender == owner, "You are not the owner of this contract");
        _;
    }


}