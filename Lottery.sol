// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Lottery {
    address public owner;

    enum Stage {Init, Reg, Bid, Done}
    Stage public stage;
    uint256 public lotteryTicketNumber = 1; // Track the lottery ticket number

    struct Person {
        uint256 personId;
        address addr;
        uint256 remainingTokens;
        uint256 registrations;
    }

    struct Item {
        uint256 itemId;
        address[] itemTokens;
    }

    mapping(address => Person) public bidders;
    Item[] public items;
    uint256 public bidderCount = 0;
    address[] public winners;
    address public beneficiary;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    modifier atStage(Stage _stage) {
        require(stage == _stage, "Invalid stage");
        _;
    }

    constructor() {
        owner = msg.sender;
        beneficiary = msg.sender;
        stage = Stage.Init; // Set initial stage to registration
    }

    function advanceState() public onlyOwner {
        require(stage != Stage.Done, "Cannot advance past Done stage");
        stage = Stage(uint8(stage) + 1);
    }

    function register() public payable atStage(Stage.Reg) {
        require(msg.sender != owner, "Owner cannot register");
        require(bidders[msg.sender].addr == address(0), "Already registered");
        // Uncomment this for production
        // require(msg.value >= 0.005 ether, "Insufficient Ether sent");
        require(bidders[msg.sender].remainingTokens + 5 <= type(uint256).max, "Maximum number of players reached");

        bidders[msg.sender].personId = bidderCount;
        bidders[msg.sender].addr = msg.sender;
        bidders[msg.sender].remainingTokens += 5;
        bidderCount++;

        emit RegistrationSuccess(msg.sender, 5);
    }

    function addItem() public onlyOwner atStage(Stage.Init) {
        uint256 itemId = items.length;
        address[] memory emptyArray;
        items.push(Item({itemId: itemId, itemTokens: emptyArray}));
    }

    function getItems() public view returns (uint256[] memory itemIds, uint256[] memory bidsCount) {
        itemIds = new uint256[](items.length);
        bidsCount = new uint256[](items.length);

        for (uint256 i = 0; i < items.length; i++) {
            itemIds[i] = items[i].itemId;
            bidsCount[i] = items[i].itemTokens.length;
        }

        return (itemIds, bidsCount);
    }

    function bid(uint256 _itemId, uint256 _count) public payable atStage(Stage.Bid) {
        require(_count > 0 && _count <= bidders[msg.sender].remainingTokens, "Invalid bid");
        require(_itemId < items.length, "Invalid item ID");

        bidders[msg.sender].remainingTokens -= _count;

        for (uint256 i = 0; i < _count; i++) {
            items[_itemId].itemTokens.push(msg.sender);
        }

        emit BidPlaced(msg.sender, _itemId, _count);
    }

    function revealWinners() public onlyOwner atStage(Stage.Done) {
        for (uint256 id = 0; id < items.length; id++) {
            if (items[id].itemTokens.length > 0) {
                uint256 randomIndex = random(id);
                address winnerAddress = items[id].itemTokens[randomIndex];

                // Emit Winner event
                emit Winner(winnerAddress, id, lotteryTicketNumber);
                lotteryTicketNumber++;
            }
        }
    }

    function getWinners() public view returns (address[] memory, uint256[] memory, uint256[] memory) {
        address[] memory _winners = new address[](items.length);
        uint256[] memory itemIds = new uint256[](items.length);
        uint256[] memory lotteryTickets = new uint256[](items.length);

        for (uint256 id = 0; id < items.length; id++) {
            itemIds[id] = items[id].itemId;

            if (items[id].itemTokens.length > 0) {
                uint256 randomIndex = random(id);
                _winners[id] = items[id].itemTokens[randomIndex];
                lotteryTickets[id] = lotteryTicketNumber + id;
            } else {
                _winners[id] = address(0);
                lotteryTickets[id] = 0;
            }
        }

        return (_winners, itemIds, lotteryTickets);
    }

    function random(uint256 id) internal view returns (uint256) {
        return uint256(
            keccak256(
                abi.encodePacked(
                    block.difficulty,
                    block.timestamp,
                    block.number,
                    items[id].itemTokens.length
                )
            )
        ) % items[id].itemTokens.length;
    }

    function withdraw() public onlyOwner atStage(Stage.Done) {
        // Transfer all test Ether from the contract to the owner
        payable(owner).transfer(address(this).balance);
    }

    function reset() public onlyOwner {
        // Reset the contract by clearing items, registered players, and winners
        delete items;
        bidderCount = 0;
        delete winners;

        // Set the stage back to Reg
        stage = Stage.Reg;
    }

    event BidPlaced(address indexed bidder, uint256 indexed itemId, uint256 count);
    event RegistrationSuccess(address indexed registrant, uint256 tokensReceived);
    event Winner(address indexed winner, uint256 indexed itemId, uint256 lotteryTicket);
}
