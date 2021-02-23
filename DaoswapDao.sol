pragma solidity=0.5.16;
pragma experimental ABIEncoderV2;
import './interfaces/IDaoswapDao.sol';
import './libraries/SafeMath.sol';
import './interfaces/IERCMint20.sol';
import './interfaces/IDelegate.sol';
import './interfaces/IDaoswapERC20.sol';
import './interfaces/IDaoswapPair.sol';

contract DaoswapDao is IDaoswapDao {
    using SafeMath  for uint;
    mapping(address=>uint256[]) public swap_block_liquid;
	mapping(address=>uint256[]) public swap_block_number;
    mapping(address=>uint256) public swap_shares;
    address public voting_addr;
    address public delegate_addr;
    address public erc_addr;
	uint public  min_deaultblock_step;
	uint256 public  perblockreward;
	uint public  granularity;
	bool public  vote_start;
	uint public current_weight;
	mapping(address=>uint32) public swap_weight;
    address owner;
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);
    constructor(
                address _delegate_addr,
                address _erc_addr,
                uint _min_deaultblock_step,
                uint _perblockreward,
                uint _granularity) public {
        owner = msg.sender;
        delegate_addr =  _delegate_addr;
        erc_addr =  _erc_addr;
        min_deaultblock_step = _min_deaultblock_step;
        perblockreward = _perblockreward.mul(10**18);
        granularity = _granularity.mul(10**18);
        vote_start = false;
    }
	function getercBalanceof(address user)external view returns (uint){
	    return IERCMint20(erc_addr).balanceOf(user);
	}
	function changeWeight(address swap_addr ,uint32 weight) external swapexist(swap_addr){
	    require(msg.sender == owner);
	    for(uint i = 0;i < allPairs.length;i++){
	        calcprice(allPairs[i],1);
	    }
	    current_weight = current_weight.sub(swap_weight[swap_addr]).add(weight);
	    swap_weight[swap_addr] = weight;
	}
    function changeMintErc(address _erc_addr) external{
        require(msg.sender == owner);
        erc_addr = _erc_addr;
    }
	function changeVoting(address vote_addr,bool _vote_start) external{
	    require(msg.sender == owner);
	    voting_addr = vote_addr;
	    vote_start = _vote_start;
	}
	function changeDelegate(address _delegate_addr) external{
	    require(msg.sender == owner);
	    delegate_addr = _delegate_addr;
	}
    function calcreward(address user, address swap_addr, uint256 shares,uint256 lastGetRewardBlock,uint8 mode) internal {
	    uint reward = 0;
        if(swap_block_number[swap_addr].length > 0){
            uint end_block = SafeMath.max(swap_block_number[swap_addr][swap_block_number[swap_addr].length.sub(1)],lastGetRewardBlock);
            uint block_counts = 0;
            if((mode == 1)&&(block.number > end_block)){
                if(current_weight != 0 && swap_shares[swap_addr] != 0){
                    block_counts = block.number.sub(end_block);
                    reward =reward.add(block_counts.mul(perblockreward).mul(swap_weight[swap_addr]).mul(shares)/current_weight/ swap_shares[swap_addr]);
                }
                IERCMint20(erc_addr).setAddressBlock(user,swap_addr,block.number);
            }
            else{
                IERCMint20(erc_addr).setAddressBlock(user,swap_addr,end_block);
            }
            if(swap_block_number[swap_addr].length > 1){
                for(uint i = swap_block_number[swap_addr].length.sub(1);i >0;i--){
                    if(lastGetRewardBlock >= swap_block_number[swap_addr][i]){
                        break;
                    }
                    block_counts = swap_block_number[swap_addr][i].sub(SafeMath.max(swap_block_number[swap_addr][i-1],lastGetRewardBlock));
                    reward = reward.add(swap_block_liquid[swap_addr][i].mul(shares).mul(block_counts) / granularity);
                    if(lastGetRewardBlock >= swap_block_number[swap_addr][i-1]){
                        break;
                    }
                    if(swap_block_number[swap_addr].length > 1500){
                        if(swap_block_number[swap_addr].length.sub(i) > 1500){
                            break;
                        }
                    }
                }
            }
        }
        else{
            IERCMint20(erc_addr).setAddressBlock(user,swap_addr,lastGetRewardBlock);
        }
        if(reward > 0){
            IERCMint20(erc_addr).mint(user,reward);
            IDelegate.DelegatePre[] memory preuser =  IDelegate(delegate_addr).getDelegateRewardRanks(user);
            for(uint i = 0;i < preuser.length;i++){
                if(preuser[i].delegateAddr == address(0) || preuser[i].delegateReward == 0){
                    continue;
                }
                if(reward.mul(preuser[i].delegateReward) / 100 > 0){
                    IERCMint20(erc_addr).mint(preuser[i].delegateAddr,reward.mul(preuser[i].delegateReward) / 100 );
                }
            }
        }

	}
    function calcprice(address swap_addr,uint min_block_steps) internal{
		if(block.number >= swap_block_number[swap_addr][swap_block_number[swap_addr].length.sub(1)] + min_block_steps){
		    if(current_weight == 0 || swap_shares[swap_addr] == 0){
		        swap_block_liquid[swap_addr].push(0);
		    }
		    else{
		        swap_block_liquid[swap_addr].push(perblockreward.mul(swap_weight[swap_addr]).mul(granularity)/ current_weight/swap_shares[swap_addr]);
		    }
		    swap_block_number[swap_addr].push(block.number);
		}
    }
    modifier swapexist(address _swap_addr){
        bool exist = false;
        address token_0 = IDaoswapPair(_swap_addr).token0();
        address token_1 = IDaoswapPair(_swap_addr).token1();
        address _pair = getPair[token_0][token_1];
        if(_pair == _swap_addr){
            exist = true;
        }
        require(exist,'Don`t have this pair');
        _;
    }
    function getReward(address swap_addr) external swapexist(swap_addr){
        uint256 start_block = IERCMint20(erc_addr).getStartblock(msg.sender,swap_addr);
        //require(start_block > swap_block_number[swap_addr][swap_block_number[swap_addr].length.sub(1)]);
        uint256 shares = IDaoswapERC20(swap_addr).balanceOf(msg.sender);
        require(shares > 0,'this account has no share');
        require(swap_shares[swap_addr] > 0,'this swap has no share');
        calcreward(msg.sender,swap_addr,shares,start_block,1);

    }
    function changeSwapShare(address user,uint256 origin_amount,uint256 amount,bool add)external swapexist(msg.sender){
		uint256 start_block = IERCMint20(erc_addr).getStartblock(user,msg.sender);
        if(swap_block_number[msg.sender].length > 0){
            if(swap_block_liquid[msg.sender][swap_block_liquid[msg.sender].length.sub(1)] == 0){
                calcprice(msg.sender,1);
            }
            else{
                calcprice(msg.sender,min_deaultblock_step);
            }
        }
		else{
            calcprice(msg.sender,min_deaultblock_step);
        }
        calcreward(user,msg.sender,origin_amount,start_block,0);
		 if(add){
            swap_shares[msg.sender]=swap_shares[msg.sender].add(amount);
        } else{
            swap_shares[msg.sender]= swap_shares[msg.sender].sub(amount);
        }
    }
    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }
    function createPair(address pair) external {
        if(!vote_start){
            require(msg.sender == owner);
        }
        else{
            require((msg.sender == voting_addr) && (voting_addr != address(0)));
        }
        address tokenA = IDaoswapPair(pair).token0();
        address tokenB = IDaoswapPair(pair).token1();
        require(tokenA != tokenB, 'Daoswap: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'Daoswap: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'Daoswap: PAIR_EXISTS'); // single check is sufficient
        /*
        bytes memory bytecode = type(DaoswapPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IDaoswapPair(pair).initialize(token0, token1);*/
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        swap_block_liquid[pair].push(0);
        swap_block_number[pair].push(block.number);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

}
