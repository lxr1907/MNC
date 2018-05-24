pragma solidity ^0.4.18;
interface tokenRecipient { function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData) public; }
contract owned {
    address public owner;

    function owned() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) onlyOwner public {
        owner = newOwner;
    }
}
contract LxrContract is owned{
     // 令牌的公有变量
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    // 18 decimals 极力推荐使用默认值，尽量别改
    uint256 public totalSupply;
    //合约拥有者
    address public owner;
    //矿工账号
    address public miner;
    // 创建所有账户余额数组
    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;
    
    uint256 public buyPrice=1;
    uint256 public sellPrice=1;

    // 在区块链上创建一个公共事件，它触发就会通知所有客户端
    event Transfer(address indexed from, address indexed to, uint256 value);

    // 通知客户端销毁数额
    event Burn(address indexed from, uint256 value);

    /**
     * 合约方法
     *
     * 初始化合约，将最初的令牌打入创建者的账户中
     */
    function LxrContract(
        uint256 initialSupply,
        string tokenName,
        string tokenSymbol,address initialMiner
    ) public {
        totalSupply = initialSupply * 10 ** uint256(decimals);  // 更新总发行量
        balanceOf[msg.sender] = totalSupply;                // 给创建者所有初始令牌
        name = tokenName;                                   // 设置显示名称
        symbol = tokenSymbol;                               // 设置显示缩写，例如比特币是BTC
        owner=msg.sender;
        miner=initialMiner;
    }

    /**
     * 内部转账，只能被该合约调用
     */
    function _transfer(address _from, address _to, uint _value) internal {
        // 检查发送者是否拥有足够的币
        require(balanceOf[_from] >= _value);
        // 检查越界
        require(balanceOf[_to] + _value > balanceOf[_to]);
        // 从发送者扣币
        balanceOf[_from] -= _value;
        // 给接收者加相同数量币
        balanceOf[_to] += _value;
        Transfer(_from, _to, _value);
    }

    /**
     * 发送令牌
     *
     * 从你的账户发送个`_value` 令牌到 `_to` 
     *
     * @param _to 接收地址
     * @param _value 发送数量
     */
    function transfer(address _to, uint256 _value) public {
        _transfer(msg.sender, _to, _value);
    }
    
    /**
     *增发
     * 
     */
    function mintToken(address target, uint256 mintedAmount) onlyOwner public{
        balanceOf[target] += mintedAmount;
        totalSupply += mintedAmount;
        Transfer(0, this, mintedAmount);
        Transfer(this, target, mintedAmount);
    }
    //设置购买价格
    function setBuyPrices(uint256 newBuyPrice)  public {
        require(msg.sender == owner);
        buyPrice = newBuyPrice;
    }
    //设置出售价格
    function setSellPrices(uint256 newSellPrice)  public {
        require(msg.sender == owner);
        sellPrice = newSellPrice;
    }

    /// @notice 使用以太坊购买token
    function buy() payable public {
        uint amount = msg.value / buyPrice;               // calculates the amount
        _transfer( this,msg.sender, amount);                // makes the transfers
    }
    //出售
     function sell(uint256 amount) public {
        require(this.balance >= amount * sellPrice);      // checks if the contract has enough ether to buy
        _transfer(msg.sender, this, amount);              // makes the transfers
        msg.sender.transfer(amount * sellPrice);          // sends ether to the seller. It's important to do this last to avoid recursion attacks
    }
}