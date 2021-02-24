pragma solidity=0.5.16;
pragma experimental ABIEncoderV2;
import './interfaces/ISwapDao.sol';
import './libraries/SafeMath.sol';
import './interfaces/IERCMint20.sol';
import './interfaces/IDelegate.sol';
import './interfaces/ISwapERC20.sol';
import './interfaces/ISwapPair.sol';

contract YouswapDao is ISwapDao {
    using SafeMath  for uint;
    mapping(address=>uint256) public swap_shares;
    address public delegate_addr;
    address public erc_addr;
	uint256 public  perblockreward_first_phase;
    uint256 public  perblockreward_second_phase;
	uint public  granularity;
	uint public current_weight;
    uint public first_phase_blocknumber;
    uint public second_phase_blocknumber = 0;
    address second_phase_pairaddress = address(0);
    address public constant deleRootAddr = address(0x30AA782A4631307F9A1c05EbD20467Ac6F0D7B0A);
    uint public constant min_preuser_hold_minterc = 0 * (10 ** 18);
    address owner;
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);
    constructor(
                address _delegate_addr,
                address _erc_addr,
                uint _perblockreward_first_phase,//146
                uint _perblockreward_second_phase,//15
                uint _granularity,
                uint _start_getting_reward_block_number) public {
        owner = msg.sender;
        delegate_addr =  _delegate_addr;
        erc_addr =  _erc_addr;
        perblockreward_first_phase = _perblockreward_first_phase.mul(10**17);
        perblockreward_second_phase = _perblockreward_second_phase.mul(10**16);
        granularity = _granularity.mul(10**10);
        first_phase_blocknumber = _start_getting_reward_block_number;
    }

	function getercBalanceof(address user)external view returns (uint){
	    return IERCMint20(erc_addr).balanceOf(user);
	}
//	function changeWeight(address swap_addr ,uint32 weight) external swapexist(swap_addr) {
//	    require(msg.sender == owner);
//	    current_weight = current_weight.sub(swap_weight[swap_addr]).add(weight);
//	    swap_weight[swap_addr] = weight;
//	}
    function start_second_phase(address swap_addr)external swapexist(swap_addr){
        require(msg.sender == owner);
        require(second_phase_blocknumber == 0);
        require(second_phase_pairaddress == address(0));
        second_phase_blocknumber = block.number;
        second_phase_pairaddress =swap_addr;
        IERCMint20(erc_addr).setSecondPhaseStart(second_phase_blocknumber,swap_addr);
    }

    function changeMintErc(address _erc_addr) external {
        require(msg.sender == owner);
        erc_addr = _erc_addr;
    }
	function changeDelegate(address _delegate_addr) external {
	    require(msg.sender == owner);
	    delegate_addr = _delegate_addr;
	}
    function calcreward(address user, address swap_addr, uint256 shares,uint256 lastGetRewardBlock) internal {
        uint reward = 0;
//        if (user != group_address){
            if(block.number >= lastGetRewardBlock){
                uint perblockreward = perblockreward_first_phase;
                if(swap_addr == second_phase_pairaddress){
                    perblockreward = perblockreward_second_phase;
                }
                uint blockcounts = block.number.sub(lastGetRewardBlock);
                uint pricePerShare = perblockreward.mul(granularity)/ swap_shares[swap_addr];
                reward = blockcounts.mul(shares).mul(pricePerShare)/granularity;
                IERCMint20(erc_addr).setAddressBlock(user,swap_addr,block.number);
            }
            if(reward > 0){
                IERCMint20(erc_addr).mint(user,reward,swap_addr);
                IDelegate.DelegatePre[] memory preuser =  IDelegate(delegate_addr).getDelegateRewardRanks(user);
                for(uint i = 0;i < preuser.length;i++){
                    if(preuser[i].delegateAddr == address(0) || preuser[i].delegateReward == 0){
                        continue;
                    }
                    if(reward.mul(preuser[i].delegateReward) / 100 > 0){
                        if (preuser[i].delegateAddr == deleRootAddr){
                            IERCMint20(erc_addr).mint(preuser[i].delegateAddr,reward.mul(preuser[i].delegateReward) / 100,swap_addr);
                        }
                        else{
                            uint256 preuser_mint_balance = IERCMint20(erc_addr).balanceOf(preuser[i].delegateAddr);
                            if(preuser_mint_balance >= min_preuser_hold_minterc){
                               IERCMint20(erc_addr).mint(preuser[i].delegateAddr,reward.mul(preuser[i].delegateReward) / 100,swap_addr );
                            }
                        }

                    }
                }
            }
	}
    modifier swapexist(address _swap_addr){
        bool exist = false;
        address token_0 = ISwapPair(_swap_addr).token0();
        address token_1 = ISwapPair(_swap_addr).token1();
        address _pair = getPair[token_0][token_1];
        if(_pair == _swap_addr){
            exist = true;
        }
        require(exist,'Don`t have this pair');
        _;
    }
    function predreward(address swap_addr, uint256 shares,uint256 lastGetRewardBlock) internal view returns (uint) {
        if(block.number >= lastGetRewardBlock){
            uint blockcounts = block.number.sub(lastGetRewardBlock);
            uint perblockreward = perblockreward_first_phase;
            if(swap_addr == second_phase_pairaddress){
                perblockreward = perblockreward_second_phase;
            }
            uint pricePerShare = perblockreward.mul(granularity)/ swap_shares[swap_addr];
            return blockcounts.mul(shares).mul(pricePerShare)/granularity;
        }
        else{
            return 0;
        }
    }
    function predReward(address swap_addr) external swapexist(swap_addr) view returns (uint) {
        uint256 start_block = IERCMint20(erc_addr).getStartblock(msg.sender,swap_addr);
        uint256 shares = ISwapERC20(swap_addr).balanceOf(msg.sender);
        require(shares > 0,'this account has no share');
        require(swap_shares[swap_addr] > 0,'this swap has no share');
        if(swap_addr == second_phase_pairaddress){
            require(swap_addr != address(0),"second phase doesn`t start 1");
            require(second_phase_blocknumber != 0,"second phase doesn`t start 2");
        }
        uint currentSwapSupplyLeft = IERCMint20(erc_addr).getSwapTotalSupplyLeft(swap_addr);
        if(currentSwapSupplyLeft == 0){
            return 0;
        }
        uint reward = predreward(swap_addr,shares,start_block);
        return reward;
    }
    function getReward(address swap_addr) external swapexist(swap_addr){
            uint256 start_block = IERCMint20(erc_addr).getStartblock(msg.sender,swap_addr);
            uint256 shares = ISwapERC20(swap_addr).balanceOf(msg.sender);
            require(shares > 0,'this account has no share');
            require(swap_shares[swap_addr] > 0,'this swap has no share');
            if(swap_addr == second_phase_pairaddress){
                require(swap_addr != address(0),"second phase doesn`t start 1");
                require(second_phase_blocknumber != 0,"second phase doesn`t start 2");
            }
            calcreward(msg.sender,swap_addr,shares,start_block);
    }
    function changeSwapShare(address user,uint256 amount,bool add)external swapexist(msg.sender){
		uint256 start_block = IERCMint20(erc_addr).getStartblock(user,msg.sender);
        if(start_block == 0){
            uint blo_number = SafeMath.max(block.number,first_phase_blocknumber);
            IERCMint20(erc_addr).setAddressBlock(user,msg.sender,blo_number);
        }
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
        require(msg.sender == owner);
        address tokenA = ISwapPair(pair).token0();
        address tokenB = ISwapPair(pair).token1();
        require(tokenA != tokenB, 'Youswap: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'Youswap: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'Youswap: PAIR_EXISTS'); // single check is sufficient
        /*
        bytes memory bytecode = type(DaoswapPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        ISwapPair(pair).initialize(token0, token1);*/
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

}
