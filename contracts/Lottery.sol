//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";

error Lottery__NotEnoughETHEntered();
error Lottery__transferFailed();
error Lottery__NotOpen();
error Lottery__UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 lotteryState);

/**@title A sample Raffle Contract
 * @author Benjamin Lecomte with the huge help of Patrick Collins
 * @notice This contract is for creating a sample raffle contract
 * @dev This implements the Chainlink VRF Version 2
 */

contract Lottery is VRFConsumerBaseV2, KeeperCompatibleInterface {
    /* Type declarations */
    enum LotteryState {
        //similar to a uint256 0 = OPEN; 1 = CALCULATING
        OPEN,
        CALCULATING
    }

    /* State Variables */
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    //Lottery variables
    address private s_recentWinner;
    LotteryState private s_lotteryState;
    uint256 private s_lastTimeStamp;
    uint256 private immutable i_interval;

    /*Events*/
    event LotteryEnter(address indexed player); //Revert the name of the function it will be used in
    event RequestedLotteryWinner(uint256 indexed requestId); //indexed makes the parameter easier to search, 3 max
    event WinnerPicked(address indexed winner);

    /*Functions*/
    constructor(
        address vrfCoordinatorV2, //Available at this address, contract which is gonna check the randomness: https://docs.chain.link/docs/vrf/v2/supported-networks/
        uint256 entranceFee,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        uint256 interval
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        //Specifying parent's constructor parameter. Syntax: https://docs.soliditylang.org/en/develop/contracts.html#arguments-for-base-constructors
        i_entranceFee = entranceFee;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2); //Needs to be specified as well as the variables below
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_lotteryState = LotteryState.OPEN;
        s_lastTimeStamp = block.timestamp;
        i_interval = interval;
    }

    function enterLottery() public payable {
        if (msg.value < i_entranceFee) {
            revert Lottery__NotEnoughETHEntered();
        }
        if (s_lotteryState != LotteryState.OPEN) {
            revert Lottery__NotOpen();
        }
        s_players.push(payable(msg.sender));
        emit LotteryEnter(msg.sender);
    }

    /**
     * @notice See documentation for more information
     * @dev This is the function that the chainlink Keeper nodes call
     * They look for the "upkeepNeeded" to return true
     * The following should be true in order to return true:
     * 1. Our time interval has passed
     * 2. the lottery has at least 1 player and some ETH
     * 3. Our subscription is funded with LINK
     * 4. The lottery should be in an "open" state
     */
    function checkUpkeep(
        bytes memory /*checkData*/ //memory instead of calldata because we are passing some string below with checkUpkeep
    )
        public
        override
        view
        returns (
            bool upkeepNeeded,
            bytes memory /*performData*/
        )
    {
        bool isOpen = (LotteryState.OPEN == s_lotteryState);
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool hasPlayers = (s_players.length > 0);
        bool hasBalance = (address(this).balance > 0);
        upkeepNeeded = (isOpen && timePassed && hasPlayers && hasBalance);
    }

    /*Initially named requestRandomWinner*/
    function performUpkeep(
        bytes calldata /*performData*/
    ) external override {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Lottery__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_lotteryState)
            );
        }
        s_lotteryState = LotteryState.CALCULATING;
        //Request random winner in a 2 transaction process
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, //keyHash (max gas you are willing to pay in wei)
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit RequestedLotteryWinner(requestId);
    }

    function fulfillRandomWords(
        //override fulfillRandomWords function in VRFConsumerBaseV2
        uint256, /*requestId*/ //We won't use it but we know the function needs it
        uint256[] memory randomWords //array of asked random number (which is gonna be 1 slot long here)
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length; //modulo
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_lotteryState = LotteryState.OPEN;
        s_players = new address payable[](0); //Resetting the array of players
        s_lastTimeStamp = block.timestamp;
        //Sending the contract balance to the winner
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Lottery__transferFailed();
        }
        emit WinnerPicked(recentWinner);
    }

    /* View; Pure functions */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getLotteryState() public view returns (LotteryState) {
        return s_lotteryState;
    }

    function getNumWords() public pure returns (uint256) { //pure instead of view because it read a constant
        return NUM_WORDS;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }

    function getLatestTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRequestConfirmations() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }
    function getInterval() public view returns (uint256) {
        return i_interval;
    }
}
