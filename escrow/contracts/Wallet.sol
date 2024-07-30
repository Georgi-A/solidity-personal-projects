// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

contract Wallet {
    enum Status {
        Requested,
        Approved,
        Rejected,
        Disputed
    }

    enum Vote {
        For,
        Against
    }

    struct Request {
        address spender;
        uint256 amount;
        mapping(address => bool) hasVoted;
        mapping(address => Vote) vote;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 requestedAt;
        Status status;
        bool spent;
    }

    uint256 public reqCounter;
    uint256 public participantsCount;
    mapping(uint256 => Request) public requests;
    mapping(address => uint256) public deposits;
    mapping(address => uint256) public addrSpent;
    mapping(address => bool) public participants;

    event Deposit(address indexed depositor, uint256 indexed amount);
    event Requested(address indexed requestor, uint256 indexed amount);
    event Voted(
        uint256 indexed requestNumber,
        address indexed voter,
        Vote vote,
        Status status
    );
    event Withdraw(address indexed spender, uint256 indexed amount);

    constructor(address[] memory _participants) payable {
        for (uint i = 0; i < _participants.length; i++) {
            participants[_participants[i]] = true;
            participantsCount++;
        }
    }

    function depositFunds() external payable {
        require(participants[msg.sender], "You are not participant");
        deposits[msg.sender] = msg.value;
    }

    function requestWithdraw(uint256 _amount) external {
        require(participants[msg.sender], "You are not participant");
        Request storage request = requests[reqCounter];
        request.spender = msg.sender;
        request.amount = _amount;
        request.status = Status.Requested;
        request.spent = false;
        request.requestedAt = block.timestamp;
        reqCounter++;

        emit Requested(msg.sender, _amount);
    }

    function withdraw(uint256 _index) external {
        Request storage request = requests[_index];
        require(
            address(this).balance >= request.amount,
            "Insufficient contract balance"
        );
        require(request.spender == msg.sender, "Not owner of request");
        require(request.status == Status.Approved, "Request not approved");
        require(request.spent == false, "Already spent");
        require(
            request.requestedAt + 24 hours <= block.timestamp,
            "Voting not closed"
        );

        request.spent = true;
        addrSpent[msg.sender] = request.amount;

        (bool sent, ) = msg.sender.call{value: request.amount}("");
        require(sent, "Transaction failed");

        emit Withdraw(msg.sender, request.amount);
    }

    function castVote(uint256 _index, uint256 _vote) external {
        Request storage request = requests[_index];
        require(participants[msg.sender], "You are not participant");
        require(_vote == 1 || _vote == 2, "Vote not valid");
        require(request.spender != msg.sender, "Requestor cannot vote");
        require(request.hasVoted[msg.sender] == false, "Already Voted");
        require(
            request.requestedAt + 24 hours >= block.timestamp,
            "Voting closed"
        );

        request.hasVoted[msg.sender] = true;
        request.vote[msg.sender] = _getVote(_vote);

        // Count Votes For/Against
        if (_vote == 1) {
            request.votesFor++;
        } else {
            request.votesAgainst++;
        }

        _updateStatus(_index);

        emit Voted(
            _index,
            msg.sender,
            request.vote[msg.sender],
            request.status
        );
    }

    function changeVote(uint256 _index) external {
        Request storage request = requests[_index];
        require(request.hasVoted[msg.sender] == true, "Have not voted");
        require(
            request.requestedAt + 24 hours >= block.timestamp,
            "Voting closed"
        );

        if (request.vote[msg.sender] == Vote.For) {
            request.votesFor--;
            request.votesAgainst++;
            request.vote[msg.sender] = Vote.Against;
        } else {
            request.votesFor++;
            request.votesAgainst--;
            request.vote[msg.sender] = Vote.For;
        }

        _updateStatus(_index);
    }

    // Get Wallet balance
    function getBalance() external view returns (uint256 balance) {
        balance = address(this).balance;
    }

    // Get total spent by address
    function getSpentByAddr(
        address _participant
    ) external view returns (uint256 spent) {
        spent = addrSpent[_participant];
    }

    // Get total deposits by address
    function getDepositsByAddr(
        address _participant
    ) external view returns (uint256 deposit) {
        deposit = deposits[_participant];
    }

    // Set Status for Request
    function _updateStatus(uint256 _index) internal {
        Request storage request = requests[_index];
        uint256 votesCount = request.votesAgainst + request.votesFor;

        // Set to Approved if For votes are above threshold
        if ((participantsCount) / 2 <= request.votesFor) {
            request.status = Status.Approved;
            // Set to Rejected if Against votes are above threshold
        } else if ((participantsCount) / 2 <= request.votesAgainst) {
            request.status = Status.Rejected;
        }

        // Set to Disputed if equal votes For/Against
        if (
            votesCount == participantsCount - 1 &&
            request.votesAgainst == request.votesFor
        ) {
            request.status = Status.Disputed;
        }
    }

    // Update number to Vote type
    function _getVote(uint256 _vote) internal pure returns (Vote vote) {
        // Vote For == 1/ Vote Against == 2
        if (_vote == 1) {
            vote = Vote.For;
        } else if (_vote == 2) {
            vote = Vote.Against;
        }
    }
}
