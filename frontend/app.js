// REPLACE THESE WITH YOUR ACTUAL DEPLOYED ADDRESSES LATER
// Обновлено адресами из твоего успешного деплоя в Sepolia
const TOKEN_ADDRESS = "0x3Ce36d4B0E96b6eD8CA258bad39015E0b8Db4054"; 
const GOVERNOR_ADDRESS = "0xEE9D6208c70D501e2358BdcD4c4B3c5535ac802A";

const TOKEN_ABI = [
    "function balanceOf(address account) view returns (uint256)",
    "function getVotes(address account) view returns (uint256)",
    "function delegates(address account) view returns (address)",
    "function delegate(address delegatee)"
];

const GOVERNOR_ABI = [
    "function state(uint256 proposalId) view returns (uint8)",
    "function castVote(uint256 proposalId, uint8 support)",
    "function proposalVotes(uint256 proposalId) view returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes)"
];

const PROPOSAL_STATES = ["Pending", "Active", "Canceled", "Defeated", "Succeeded", "Queued", "Expired", "Executed"];

let provider, signer, tokenContract, governorContract;

document.getElementById('connectWalletBtn').addEventListener('click', async () => {
    if (window.ethereum) {
        provider = new ethers.BrowserProvider(window.ethereum);
        await provider.send("eth_requestAccounts", []);
        signer = await provider.getSigner();
        const address = await signer.getAddress();
        
        document.getElementById('walletStatus').innerText = "Connected";
        document.getElementById('walletAddress').innerText = address;

        tokenContract = new ethers.Contract(TOKEN_ADDRESS, TOKEN_ABI, signer);
        governorContract = new ethers.Contract(GOVERNOR_ADDRESS, GOVERNOR_ABI, signer);

        document.getElementById('delegateBtn').disabled = false;
        document.getElementById('fetchProposalBtn').disabled = false;

        updateTokenInfo(address);
    } else {
        alert("Please install MetaMask!");
    }
});

async function updateTokenInfo(address) {
    try {
        const balance = await tokenContract.balanceOf(address);
        const votes = await tokenContract.getVotes(address);
        const delegate = await tokenContract.delegates(address);

        document.getElementById('tokenBalance').innerText = ethers.formatEther(balance);
        document.getElementById('votingPower').innerText = ethers.formatEther(votes);
        document.getElementById('currentDelegate').innerText = delegate;
    } catch (e) {
        console.log("Connect contracts first");
    }
}

document.getElementById('delegateBtn').addEventListener('click', async () => {
    const delegatee = document.getElementById('delegateAddress').value;
    if (ethers.isAddress(delegatee)) {
        try {
            const tx = await tokenContract.delegate(delegatee);
            await tx.wait();
            alert("Delegation successful!");
            updateTokenInfo(await signer.getAddress());
        } catch (error) {
            console.error(error);
            alert("Delegation failed. Check console.");
        }
    } else {
        alert("Invalid address format.");
    }
});

document.getElementById('fetchProposalBtn').addEventListener('click', async () => {
    const proposalId = document.getElementById('proposalIdInput').value;
    if (!proposalId) return alert("Enter Proposal ID");

    try {
        const stateCode = await governorContract.state(proposalId);
        const { againstVotes, forVotes, abstainVotes } = await governorContract.proposalVotes(proposalId);

        document.getElementById('proposalDetails').style.display = "block";
        document.getElementById('propState').innerText = PROPOSAL_STATES[stateCode];
        document.getElementById('votesFor').innerText = ethers.formatEther(forVotes);
        document.getElementById('votesAgainst').innerText = ethers.formatEther(againstVotes);
        document.getElementById('votesAbstain').innerText = ethers.formatEther(abstainVotes);
    } catch (error) {
        console.error(error);
        alert("Failed to fetch proposal. Is the ID correct?");
    }
});

async function castVote(supportType) {
    const proposalId = document.getElementById('proposalIdInput').value;
    if (!proposalId) return alert("Enter Proposal ID");
    try {
        const tx = await governorContract.castVote(proposalId, supportType);
        await tx.wait();
        alert("Vote cast successfully!");
        document.getElementById('fetchProposalBtn').click(); 
    } catch (error) {
        console.error(error);
        alert("Voting failed. Proposal might not be 'Active' or you already voted.");
    }
}

document.getElementById('voteAgainstBtn').addEventListener('click', () => castVote(0));
document.getElementById('voteForBtn').addEventListener('click', () => castVote(1));
document.getElementById('voteAbstainBtn').addEventListener('click', () => castVote(2));