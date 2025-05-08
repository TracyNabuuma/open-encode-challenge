// Challenge: Token Vesting Contract
/*
Create a token vesting contract with the following requirements:

1. The contract should allow an admin to create vesting schedules for different beneficiaries
2. Each vesting schedule should have:
   - Total amount of tokens to be vested
   - Cliff period (time before any tokens can be claimed)
   - Vesting duration (total time for all tokens to vest)
   - Start time
3. After the cliff period, tokens should vest linearly over time
4. Beneficiaries should be able to claim their vested tokens at any time
5. Admin should be able to revoke unvested tokens from a beneficiary

Bonus challenges:
- Add support for multiple token types
- Implement a whitelist for beneficiaries
- Add emergency pause functionality

Here's your starter code:
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
contract TokenVesting is Ownable(msg.sender), Pausable, ReentrancyGuard {
    struct VestingSchedule {
        address beneficiary;
        address token;
        uint256 totalAmount;
        uint256 claimedAmount;
        uint256 startTime;
        uint256 cliff;
        uint256 duration;
        bool revoked;
    }

    // Mapping from beneficiary to vesting schedule
    mapping(address => VestingSchedule) public vestingSchedules;
    
    // Whitelist of beneficiaries
    mapping(address => bool) public whitelist;

    // Events
    event VestingScheduleCreated(address indexed beneficiary, uint256 amount);
    event TokensClaimed(address indexed beneficiary, uint256 amount);
    event VestingRevoked(address indexed beneficiary);
    event BeneficiaryWhitelisted(address indexed beneficiary);
    event BeneficiaryRemovedFromWhitelist(address indexed beneficiary);

    constructor() {}

    // Modifier to check if beneficiary is whitelisted
    modifier onlyWhitelisted(address beneficiary) {
        require(whitelist[beneficiary], "Beneficiary not whitelisted");
        _;
    }

    function addToWhitelist(address beneficiary) external onlyOwner {
        require(beneficiary != address(0), "Invalid address");
        whitelist[beneficiary] = true;
        emit BeneficiaryWhitelisted(beneficiary);
    }

    function removeFromWhitelist(address beneficiary) external onlyOwner {
        whitelist[beneficiary] = false;
        emit BeneficiaryRemovedFromWhitelist(beneficiary);
    }

    function createVestingSchedule(
        address beneficiary,
        address tokenAddress,
        uint256 amount,
        uint256 cliffDuration,
        uint256 vestingDuration,
        uint256 startTime
    ) external onlyOwner onlyWhitelisted(beneficiary) whenNotPaused {
        require(beneficiary != address(0), "Invalid beneficiary address");
        require(tokenAddress != address(0), "Invalid token address");
        require(amount > 0, "Amount must be greater than 0");
        require(vestingDuration > 0, "Vesting duration must be greater than 0");
        require(startTime >= block.timestamp, "Start time must be in the future");
        require(vestingSchedules[beneficiary].totalAmount == 0, "Beneficiary already has a vesting schedule");

        IERC20 token = IERC20(tokenAddress);
        require(token.balanceOf(msg.sender) >= amount, "Insufficient token balance");
        
        // Transfer tokens to this contract
        require(token.transferFrom(msg.sender, address(this), amount), "Token transfer failed");

        vestingSchedules[beneficiary] = VestingSchedule({
            beneficiary: beneficiary,
            token: tokenAddress,
            totalAmount: amount,
            claimedAmount: 0,
            startTime: startTime,
            cliff: cliffDuration,
            duration: vestingDuration,
            revoked: false
        });

        emit VestingScheduleCreated(beneficiary, amount);
    }

    function calculateVestedAmount(
        address beneficiary
    ) public view returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        if (schedule.totalAmount == 0) return 0;
        
        uint256 currentTime = block.timestamp;
        if (currentTime < schedule.startTime + schedule.cliff) {
            return 0;
        } else if (currentTime >= schedule.startTime + schedule.duration) {
            return schedule.totalAmount - schedule.claimedAmount;
        } else {
            uint256 elapsedTime = currentTime - schedule.startTime;
            uint256 vestedAmount = (schedule.totalAmount * elapsedTime) / schedule.duration;
            return vestedAmount - schedule.claimedAmount;
        }
    }

    function claimVestedTokens() external nonReentrant whenNotPaused {
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        require(schedule.totalAmount > 0, "No vesting schedule found");
        require(!schedule.revoked, "Vesting schedule has been revoked");

        uint256 vestedAmount = calculateVestedAmount(msg.sender);
        require(vestedAmount > 0, "No vested tokens available");

        schedule.claimedAmount += vestedAmount;
        IERC20 token = IERC20(schedule.token);
        require(token.transfer(msg.sender, vestedAmount), "Token transfer failed");

        emit TokensClaimed(msg.sender, vestedAmount);
    }

    function revokeVesting(address beneficiary) external onlyOwner {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(schedule.totalAmount > 0, "No vesting schedule found");
        require(!schedule.revoked, "Vesting already revoked");

        uint256 vestedAmount = calculateVestedAmount(beneficiary);
        uint256 unvestedAmount = schedule.totalAmount - vestedAmount - schedule.claimedAmount;
        
        schedule.revoked = true;
        schedule.totalAmount = vestedAmount + schedule.claimedAmount;

        if (unvestedAmount > 0) {
            IERC20 token = IERC20(schedule.token);
            require(token.transfer(owner(), unvestedAmount), "Token transfer failed");
        }

        emit VestingRevoked(beneficiary);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
/*
Solution template (key points to implement):

1. VestingSchedule struct should contain:
   - Total amount
   - Start time
   - Cliff duration
   - Vesting duration
   - Amount claimed
   - Revoked status

2. State variables needed:
   - Mapping of beneficiary address to VestingSchedule
   - ERC20 token reference
   - Owner/admin address

3. createVestingSchedule should:
   - Validate input parameters
   - Create new vesting schedule
   - Transfer tokens to contract
   - Emit event

4. calculateVestedAmount should:
   - Check if cliff period has passed
   - Calculate linear vesting based on time passed
   - Account for already claimed tokens
   - Handle revoked status

5. claimVestedTokens should:
   - Calculate claimable amount
   - Update claimed amount
   - Transfer tokens
   - Emit event

6. revokeVesting should:
   - Only allow admin
   - Calculate and transfer unvested tokens back
   - Mark schedule as revoked
   - Emit event
*/