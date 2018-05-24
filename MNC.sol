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
     // ���ƵĹ��б���
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    // 18 decimals �����Ƽ�ʹ��Ĭ��ֵ���������
    uint256 public totalSupply;
    //��Լӵ����
    address public owner;
    //���˺�
    address public miner;
    // ���������˻��������
    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;
    
    uint256 public buyPrice=1;
    uint256 public sellPrice=1;

    // ���������ϴ���һ�������¼����������ͻ�֪ͨ���пͻ���
    event Transfer(address indexed from, address indexed to, uint256 value);

    // ֪ͨ�ͻ�����������
    event Burn(address indexed from, uint256 value);

    /**
     * ��Լ����
     *
     * ��ʼ����Լ������������ƴ��봴���ߵ��˻���
     */
    function LxrContract(
        uint256 initialSupply,
        string tokenName,
        string tokenSymbol,address initialMiner
    ) public {
        totalSupply = initialSupply * 10 ** uint256(decimals);  // �����ܷ�����
        balanceOf[msg.sender] = totalSupply;                // �����������г�ʼ����
        name = tokenName;                                   // ������ʾ����
        symbol = tokenSymbol;                               // ������ʾ��д��������ر���BTC
        owner=msg.sender;
        miner=initialMiner;
    }

    /**
     * �ڲ�ת�ˣ�ֻ�ܱ��ú�Լ����
     */
    function _transfer(address _from, address _to, uint _value) internal {
        // ��鷢�����Ƿ�ӵ���㹻�ı�
        require(balanceOf[_from] >= _value);
        // ���Խ��
        require(balanceOf[_to] + _value > balanceOf[_to]);
        // �ӷ����߿۱�
        balanceOf[_from] -= _value;
        // �������߼���ͬ������
        balanceOf[_to] += _value;
        Transfer(_from, _to, _value);
    }

    /**
     * ��������
     *
     * ������˻����͸�`_value` ���Ƶ� `_to` 
     *
     * @param _to ���յ�ַ
     * @param _value ��������
     */
    function transfer(address _to, uint256 _value) public {
        _transfer(msg.sender, _to, _value);
    }
    
    /**
     *����
     * 
     */
    function mintToken(address target, uint256 mintedAmount) onlyOwner public{
        balanceOf[target] += mintedAmount;
        totalSupply += mintedAmount;
        Transfer(0, this, mintedAmount);
        Transfer(this, target, mintedAmount);
    }
    //���ù���۸�
    function setBuyPrices(uint256 newBuyPrice)  public {
        require(msg.sender == owner);
        buyPrice = newBuyPrice;
    }
    //���ó��ۼ۸�
    function setSellPrices(uint256 newSellPrice)  public {
        require(msg.sender == owner);
        sellPrice = newSellPrice;
    }

    /// @notice ʹ����̫������token
    function buy() payable public {
        uint amount = msg.value / buyPrice;               // calculates the amount
        _transfer( this,msg.sender, amount);                // makes the transfers
    }
    //����
     function sell(uint256 amount) public {
        require(this.balance >= amount * sellPrice);      // checks if the contract has enough ether to buy
        _transfer(msg.sender, this, amount);              // makes the transfers
        msg.sender.transfer(amount * sellPrice);          // sends ether to the seller. It's important to do this last to avoid recursion attacks
    }
}