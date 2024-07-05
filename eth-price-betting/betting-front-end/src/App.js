import React, { useState, useEffect } from 'react';
import { ethers } from 'ethers';
import 'bootstrap/dist/css/bootstrap.min.css';
import './App.css';
import { ToastContainer, toast } from 'react-toastify';
import 'react-toastify/dist/ReactToastify.css';
import { EthPriceBettingABI } from '../src/ABI/ABI.js';

const EthPriceBettingAddress = '0x99462f1e5aA9786DF0BE453DfE3D7043bEA2bC07';
const ownerAddress = '0x0c12eB047c2CA71fa23F20A33ADDeABe02073C2F';

function App() {
  const [provider, setProvider] = useState(null);
  const [signer, setSigner] = useState(null);
  const [contract, setContract] = useState(null);
  const [account, setAccount] = useState(null);

  const [position, setPosition] = useState('');
  const [betAmount, setBetAmount] = useState('');
  const [currentPrice, setCurrentPrice] = useState(null);
  const [placedBet, setPlacedBet] = useState(null);
  const [bettingDuration, setBettingDuration] = useState('');
  const [forwarderAddr, setForwarderAddr] = useState('');
  const [endTime, setEndTime] = useState(null);

  useEffect(() => {
    const initializeEthers = async () => {
      if (window.ethereum) {
        try {
          const newProvider = new ethers.providers.Web3Provider(window.ethereum);
          const newSigner = newProvider.getSigner();
          const newContract = new ethers.Contract(EthPriceBettingAddress, EthPriceBettingABI, newSigner);

          setProvider(newProvider);
          setSigner(newSigner);
          setContract(newContract);

          const accounts = await window.ethereum.request({ method: 'eth_accounts' });
          if (accounts.length === 0) {
            const newAccounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
            setAccount(newAccounts[0]);
          } else {
            setAccount(accounts[0]);
          }
        } catch (error) {
          console.error('Error initializing ethers:', error);
        }
      } else {
        console.error('Please install MetaMask!');
      }
    };

    initializeEthers();
  }, []);

  const createBet = async () => {
    if (contract && position && betAmount) {
      try {
        if (placedBet) {
          toast.error('You have existing bet');
          return;
        }

        const value = ethers.utils.parseEther(betAmount);
        const txData = { value };

        const gasEstimate = await contract.estimateGas.createBet(position, txData);

        console.log('Gas Estimate:', gasEstimate.toString());

        const tx = await contract.createBet(position, txData);
        await tx.wait();
        toast.success('Bet created successfully!');

        setPlacedBet({
          position,
          betAmount,
        });

        setPosition('');
        setBetAmount('');
      } catch (error) {
        if (error.message.includes("Requires higher amount than 0.2 Ether")) {
          toast.error("Requires higher amount than 0.2 Ether");
        } else if (error.message.includes("You have existing bet")) {
          toast.error("You have existing bet");
        } else if (error.message.includes("Only EOA can participate")) {
          toast.error("Only EOA can participate");
        } else if (error.message.includes("Betting not open.")) {
          toast.error("Betting not open.");
        } else if (error.message.includes("Betting time finished.")) {
          toast.error("Betting time finished.");
        } else {
          toast.error(`Failed to create bet: ${error.message}`);
        }
      }
    } else {
      toast.error('Please fill in all fields.');
    }
  };

  const settleBet = async () => {
    if (contract) {
      try {
        const tx = await contract.settleBet();
        await tx.wait();
        toast.success('Bet settled successfully!');
        setPlacedBet(null); 
      } catch (error) {
        if (error.message.includes("Betting time not finished")) {
          toast.error("Betting time not finished");
        } else if (error.message.includes("You have not participated")) {
          toast.error("You have not participated");
        } else if (error.message.includes("Eth price cant be 0")) {
          toast.error("Eth price can't be 0");
        } else if (error.message.includes("Not enough funds, come back later")) {
          toast.error("Not enough funds, come back later");
        } else {
          toast.error('Failed to settle bet, betting period not finished.');
        }
      }
    }
  };

  const withdraw = async () => {
    if (contract) {
      try {
        const tx = await contract.withdraw();
        await tx.wait();
        toast.success('Withdraw successful!');
      } catch (error) {
        if (error.message.includes("No available funds")) {
          toast.error("No available funds");
        } else {
          toast.error('Failed to withdraw.');
        }
      }
    }
  };

  const openNewBettingPeriod = async () => {
    if (contract && bettingDuration) {
      try {
        const newEndTime = (parseInt(bettingDuration) * 60) + Math.floor(Date.now() / 1000);
        const tx = await contract.openNewBettingPeriod(newEndTime);
        await tx.wait();
        toast.success('New betting period opened successfully!');

        setBettingDuration('');
      } catch (error) {
        toast.error('Failed to open new betting period.');
      }
    } else {
      toast.error('Please fill in the duration.');
    }
  };

  const getCurrentPrice = async () => {
    if (contract) {
      try {
        const price = await contract.getChainlinkDataFeedLatestAnswer();
        setCurrentPrice(ethers.utils.formatUnits(price, 'wei'));
      } catch (error) {
        toast.error('Failed to get current price.');
      }
    }
  };

  const setForwarderAddress = async () => {
    if (contract && forwarderAddr) {
      try {
        const tx = await contract.setForwarder(forwarderAddr);
        await tx.wait();
        toast.success('Forwarder address set successfully!');
        setForwarderAddr('');
      } catch (error) {
        if (error.message.includes("Cant be address 0")) {
          toast.error("Can't be address 0");
        } else {
          toast.error('Failed to set forwarder address.');
        }
      }
    } else {
      toast.error('Please fill in the forwarder address.');
    }
  };

  const getEndTime = async () => {
    if (contract) {
      try {
        const endTime = await contract.getEndTime();
        setEndTime(new Date(endTime * 1000).toLocaleString());
      } catch (error) {
        toast.error('Failed to get end time.');
      }
    }
  };

  return (
    <div className="App">
      <ToastContainer />
      <header className="App-header">
        <h1>Eth Price Betting</h1>
        <div className="container">
          <div className="left-pane">
            <div className="form-group">
              <input
                type="text"
                className="form-control"
                placeholder="Position (long/short)"
                value={position}
                onChange={(e) => setPosition(e.target.value)}
              />
              <input
                type="text"
                className="form-control"
                placeholder="Bet Amount (in ETH - min 0.2 ETH)"
                value={betAmount}
                onChange={(e) => setBetAmount(e.target.value)}
              />
              <button className="btn btn-primary" onClick={createBet}>
                Create Bet
              </button>
              <button className="btn btn-info" onClick={getCurrentPrice}>
                Get Current Price
              </button>
              <button className="btn btn-secondary" onClick={getEndTime}>
                Get End Time
              </button>
              <button className="btn btn-warning" onClick={settleBet}>
                Settle Bet
              </button>
            </div>
          </div>
          <div className="right-pane">
            {currentPrice && (
              <div className="current-price">
                <h2>Current Price: <span className="price">{currentPrice}</span> USD</h2>
              </div>
            )}
            {endTime && (
              <div className="end-time">
                <h2>Betting Ends At: <span className="time">{endTime}</span></h2>
              </div>
            )}
            {placedBet && (
              <div className="placed-bet">
                <h2>Your Placed Bet:</h2>
                <p>Position: {placedBet.position}</p>
                <p>Bet Amount: {placedBet.betAmount} ETH</p>
                <p>Bet Placed at Price: {placedBet.priceAtPlacedBet} USD</p>
              </div>
            )}
          </div>
        </div>
        {account && account.toLowerCase() === ownerAddress.toLowerCase() && (
          <div className="admin-pane">
            <h2>Admin Functions</h2>
            <div className="form-group">
              <input
                type="text"
                className="form-control"
                placeholder="Betting Duration (minutes)"
                value={bettingDuration}
                onChange={(e) => setBettingDuration(e.target.value)}
              />
              <button className="btn btn-success" onClick={openNewBettingPeriod}>
                Open New Betting Period
              </button>
              <button className="btn btn-danger" onClick={withdraw}>
                Withdraw
              </button>
            </div>
            <div className="form-group">
              <input
                type="text"
                className="form-control"
                placeholder="Forwarder Address"
                value={forwarderAddr}
                onChange={(e) => setForwarderAddr(e.target.value)}
              />
              <button className="btn btn-primary" onClick={setForwarderAddress}>
                Set Forwarder Address
              </button>
            </div>
          </div>
        )}
      </header>
    </div>
  );
}

export default App;