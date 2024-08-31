// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../interfaces/IERC20.sol";

contract StakeGTK {
    IERC20 public gtkToken; // Reference to the GTK token
    address owner;
    uint256 daysInYear;
    uint256 public unlockTime;
    uint256 public contractBalance;
    address public tokenAddress;

    constructor(address _gtkTokenAddress) {
        owner = msg.sender;
        daysInYear = 365;
        unlockTime = block.timestamp + 10 days; //for testing use to jump date to 10 days adjust to taste.
        gtkToken = IERC20(_gtkTokenAddress); // GTK token address passed during contract deployment
        contractBalance = IERC20(_gtkTokenAddress).balanceOf(owner);
        tokenAddress = _gtkTokenAddress;
    }

    struct stakingPlan {
        string planName;
        uint256 duration; // Duration in days
        uint256 interestRate; // Interest rate in percentage
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

    mapping(uint8 => stakingPlan) plans; // mapping staking plan ID to plans
    mapping(address => uint256) totalAmountStakedBalances; // User's total amount staked
    mapping(address => uint256) rewardBalances; // User's reward balances in GTK
    mapping(address => uint256) totalAmountRewardedBalances; // User's total rewarded amount
    mapping(address => mapping(uint8 => userStake[])) stakesByUser; // Mapping of users to their stakes per plan

    stakingPlan[] allPlans;

    event createPlanSuccessful(
        string nameOfPlan,
        uint256 _duration,
        uint256 interestRate,
        uint8 planId
    );

    event depositSuccessful(uint _amount, address _address, string planName);

    modifier onlyOwner() {
        require(msg.sender == owner, "You are not the owner of this contract");
        _;
    }

    // Function to create staking plans
    function createPlan(
        string memory _nameOfPlan,
        uint256 _duration,
        uint256 _interestRate,
        uint8 _planId
    ) external onlyOwner {
        require(!plans[_planId].exists, "Plan ID already Exists");
        for (uint256 i = 0; i < allPlans.length; i++) {
            require(
                keccak256(abi.encodePacked(allPlans[i].planName)) !=
                    keccak256(abi.encodePacked(_nameOfPlan)),
                "Plan Name already exists."
            );
        }

        stakingPlan memory sp = stakingPlan({
            planName: _nameOfPlan,
            interestRate: _interestRate,
            planId: _planId,
            duration: _duration,
            exists: true
        });

        allPlans.push(sp);
        plans[_planId] = sp;

        emit createPlanSuccessful(
            _nameOfPlan,
            _duration,
            _interestRate,
            _planId
        );
    }

    // Function to get all staking plans
    function getAllStakingPlans()
        external
        view
        onlyOwner
        returns (stakingPlan[] memory)
    {
        return allPlans;
    }

    // Function for user to stake GTK tokens into a plan
    function stake(uint8 _planID, uint256 _amount) external {
        require(msg.sender != address(0), "Sender address is a zero address");
        require(_amount > 0, "Amount to stake must be greater than zero.");
        require(plans[_planID].planId == _planID, "Invalid plan ID");
        uint256 _userTokenBalance = gtkToken.balanceOf(msg.sender);
        require(_userTokenBalance > _amount, "Insufficient Funds.");

        // Transfer the staked tokens from the user to the contract
        require(
            gtkToken.transferFrom(msg.sender, address(this), _amount),
            "Token transfer failed"
        );

        totalAmountStakedBalances[msg.sender] += _amount;

        // Get the selected plan
        stakingPlan memory selectedPlan = plans[_planID];
        uint256 interest = calculateInterest(
            _amount,
            selectedPlan.interestRate,
            selectedPlan.duration
        );

        stakesByUser[msg.sender][_planID].push(
            userStake({
                planId: _planID,
                endTime: block.timestamp + (selectedPlan.duration * 24 * 60 * 60),
                created_at: block.timestamp,
                estimatedInterest: interest,
                amountStaked: _amount,
                isEnded: false,
                isWithdrawn: false
            })
        );
        contractBalance += _amount; //Increase Contract Balance.
        emit depositSuccessful(_amount, msg.sender, selectedPlan.planName);
    }

    // Reward mechanism for users who can withdraw
    function rewardMechanism(uint8 _planID, uint256 _index) external {
        require(msg.sender != address(0), "Address zero Detected");
        require(
            totalAmountStakedBalances[msg.sender] > 0,
            "Not a user of the system"
        );
        require(
            canWithdraw(_planID, msg.sender, _index),
            "Cannot perform reward."
        );

        userStake storage usrStk = stakesByUser[msg.sender][_planID][_index];
        usrStk.isEnded = true;
        usrStk.isWithdrawn = true;

        uint256 interest = usrStk.estimatedInterest;
        rewardBalances[msg.sender] += interest;
        totalAmountRewardedBalances[msg.sender] += interest;
    }

    function withdrawReward(uint256 _amount) external {
        require(msg.sender != address(0), "Address zero detected");
        require(
            rewardBalances[msg.sender] >= _amount,
            "Insufficient reward balance"
        );
        require(
            gtkToken.balanceOf(address(this)) >= _amount,
            "Insufficient contract balance"
        );

        rewardBalances[msg.sender] -= _amount;
        contractBalance -= _amount;

        // Transfer tokens to the user
        require(
            gtkToken.transfer(msg.sender, _amount),
            "Token withdrawal failed"
        );
    }

    function showAvailableRewardForWithdraw() public view returns (uint256) {
        return rewardBalances[msg.sender];
    }

    function getTotalAmountStakedByUser() external view returns (uint256) {
        return totalAmountStakedBalances[msg.sender];
    }

    // function withdraw(uint8 _planID, uint256 _index) external {
    //     require(msg.sender != address(0), "Address zero detected.");
    //     require(
    //         canWithdraw(_planID, msg.sender, _index),
    //         "Cannot withdraw funds."
    //     );

    //     userStake storage usrStk = stakesByUser[msg.sender][_planID][_index];
    //     uint256 interest = usrStk.estimatedInterest;
    //     uint256 totalWithdrawal = usrStk.amountStaked + interest;

    //     usrStk.isEnded = true;
    //     usrStk.isWithdrawn = true;
    //     totalAmountStakedBalances[msg.sender] -= usrStk.amountStaked;

    //     contractBalance -= totalWithdrawal;

    //     // Transfer tokens (staked + interest) to the user
    //     require(
    //         gtkToken.transfer(msg.sender, totalWithdrawal),
    //         "Withdrawal failed"
    //     );
    // }

    function canWithdraw(
        uint8 _planID,
        address _address,
        uint256 _index
    ) public view returns (bool) {
        userStake memory usrStk = stakesByUser[_address][_planID][_index];
        require(usrStk.amountStaked > 0, "No active stake on this plan.");
        require(block.timestamp >= usrStk.endTime, "Stake is still ongoing."); //This line checks the duration against the curren time
        // require(unlockTime >= usrStk.endTime, "Stake is still ongoing."); //Testing mode adjusting time here for time travel
        require(!usrStk.isEnded, "Stake has already ended.");
        require(!usrStk.isWithdrawn, "Stake reward already withdrawn.");
        return true;
    }

    function calculateInterest(
        uint256 principal,
        uint256 rate,
        uint numberOfDays
    ) public view returns (uint256) {
        uint256 timeInYears = (numberOfDays * 1e18) / daysInYear; // Time in years scaled by 1e18 for precision
        uint256 interest = (principal * rate * timeInYears) / 100e18; // Calculate interest with scaling
        return principal + interest;
    }

    function fundContract(uint256 _amount) private onlyOwner {
        gtkToken.transferFrom(tokenAddress, owner, _amount);
    }

    // function getBalance() public view returns (uint) {
    //     return contractBalance;
    // }
}
