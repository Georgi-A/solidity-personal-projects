// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

contract Wallet {
    address[] public participants;
    uint256[] public approvals;
    uint256 public reqCounter;
    mapping(uint256 => Request) public requests;
    mapping(address => uint256) public deposits;
    mapping(address => uint256) public addrSpent;

    enum Status {
        New,
        Approved,
        Rejected
    }

    struct Request {
        address spender;
        uint256 amount;
        address[] approvers;
        Status[] vote;
        Status status;
        bool spent;
    }

    constructor(address[] memory _participants) payable {
        participants = _participants;
    }

    function depositFunds() external payable {
        require(_isParticipant() == true, "You are not participant");
        deposits[msg.sender] = msg.value;
    }

    function requestWithdraw(uint256 _amount) external {
        require(_isParticipant() == true, "You are not participant");
        require(address(this).balance >= _amount, "Funds not available");
        Request memory request = Request(
            msg.sender,
            _amount,
            new address[](0),
            new Status[](0),
            Status.New,
            1
        );
        reqCounter++;
        requests[reqCounter] = request;
    }

    function withdraw(uint256 _index) external {
        Request storage request = requests[_index];
        require(_isParticipant() == true, "You are not participant");
        require(request.spender == msg.sender, "Not owner of request");
        require(request.status == Status.Approved, "Request not approved");
        require(request.spent == 1, "Already spent");

        requests[_index].spent = 2;
        addrSpent[msg.sender] = request.amount;
        (bool sent, ) = msg.sender.call{value: request.amount}("");
        require(sent, "Transaction failed");
    }

    function apprTransaction(uint256 _index, uint256 _vote) external {
        require(_isParticipant() == true, "You are not participant");
        require(_vote == 1 || _vote == 2, "Vote not valid");
        Request storage request = requests[_index];
        require(request.spender != msg.sender, "Requestor cant approve");
        request.approvers.push(msg.sender);
        request.vote.push(_getVote(_vote));

        if (_calcVotes(_index)) {
            request.status = Status.Approved;
        }
    }

    function _calcVotes(uint256 _index) internal view returns (bool) {
        uint256 approved;
        uint256 rejected;
        uint256 numberParticipants = participants.length;
        uint256 numberApprovals = requests[_index].approvers.length;

        bool aboveRequired = numberParticipants / 2 <= numberApprovals
            ? true
            : false;

        for (uint i = 0; i < requests[_index].vote.length; i++) {
            if (requests[_index].vote[i] == Status.Rejected) {
                rejected++;
            } else {
                approved++;
            }
        }

        if (numberParticipants == numberApprovals && approved > rejected) {
            return true;
        } else if (aboveRequired && rejected == 0) {
            return true;
        } else {
            return false;
        }
    }

    function _getVote(uint256 _vote) internal pure returns (Status vote) {
        if (_vote == 1) {
            vote = Status.Rejected;
        } else if (_vote == 2) {
            vote = Status.Approved;
        }
    }

    function _isParticipant() internal view returns (bool participant) {
        for (uint i = 0; i < participants.length; i++) {
            participant = participants[i] == msg.sender;
        }
    }

    function getBalance() external view returns (uint256 balance) {
        balance = address(this).balance;
    }

    function getSpentByAddr(
        address _participant
    ) external view returns (uint256 spent) {
        spent = addrSpent[_participant];
    }
}
