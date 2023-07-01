// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

interface IERC20{
    event Transfer(address indexed _from, address indexed _to, uint _value);
    event Approval(address indexed _owner, address indexed _spender, uint _value);

    function name() external returns(string memory);
    function symbol() external returns(string memory);
    function decimals() external returns(uint);
    function totalSupply() external returns(uint);
    function balanceOf(address _owner) external returns(uint);
    function transfer(address _to, uint _value) external returns(bool);
    function transferFrom(address _owner, address _spender, uint _value) external returns(bool);
    function approve(address _spender, uint _value) external returns(bool);
    function allowance(address _owner, address _spender) external returns(uint);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

contract ERC20 is IERC20, Context{
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_){
        _name = name_;
        _symbol = symbol_;
    }

    function name() public virtual override view returns(string memory){
        return _name;
    }

    function symbol() public virtual override view returns(string memory){
        return _symbol;
    }

    function decimals() public virtual override view  returns(uint){
        return 18;
    }

    function totalSupply() public virtual override view  returns(uint){
        return _totalSupply;
    }

    function balanceOf(address _owner) public virtual override view  returns(uint){
        return _balances[_owner];
    }

    function transfer(address _to, uint _value) public virtual override returns(bool){
        address owner = _msgSender();
        _transfer(owner, _to, _value);
        return true;
    }

    function allowance(address _owner, address _spender) public virtual override view  returns(uint){
        return _allowances[_owner][_spender];
    }

    function approve(address _spender, uint _value) public virtual override returns(bool){
        address owner = _msgSender();
        _approve(owner, _spender, _value);
        return true;
    }

    function _approve(address _owner, address _spender, uint _value) internal virtual returns(bool){
        require(_owner != address(0), "ERC20: approve from the zero address");
        require(_spender != address(0), "ERC20: approve to the zero address");

        _allowances[_owner][_spender] = _value;
        emit Approval(_owner, _spender, _value);
        return true;
    }

    function transferFrom(address _owner, address _spender, uint _value) public virtual override returns(bool){
        address spender = _msgSender();
        _spendAllowance(_owner, spender, _value);
        _transfer(_owner, _spender, _value);
        return true;
    }

    function increaseAllowance(address _spender, uint _addedValue) public virtual returns(bool){
        address owner = _msgSender();
        _approve(owner, _spender, _allowances[owner][_spender] + _addedValue);
        return true;
    }

    function decreaseAllowance(address _spender, uint _subtractedValue) public virtual returns(bool){
        address owner = _msgSender();
        uint256 currentAllowance = _allowances[owner][_spender];
        require(currentAllowance >= _subtractedValue, "ERC20: decreased allowance below zero");
        unchecked{
            _approve(owner, _spender, _allowances[owner][_spender] - _subtractedValue);
        }
        return true;
    }

    function _spendAllowance(address _owner, address _spender, uint _value) internal virtual{
        uint256 currentAllowance = _allowances[_owner][_spender];
        if(currentAllowance != type(uint256).max) {
            require(currentAllowance >= _value, "ERC20: spender's allowance is insufficient");
            unchecked{
                _approve(_owner, _spender, currentAllowance - _value);
            }
        }
    }

    function _beforeTokenTransfer(address _from, address _to, uint256 _value) internal virtual{
        
    }

    function _afterTokenTransfer(address _from, address _to, uint256 _value) internal virtual{
      
    }

    function _transfer(address _from, address _to, uint _value) internal virtual{
        require(_from != address(0),"ERC20: transfer from address 0");
        require(_to != address(0), "ERC20:transfer to address 0");

        _beforeTokenTransfer(_from, _to, _value);

        uint256 fromBalance = _balances[_from];
        require(fromBalance >= _value, "ERC20: transfer amount exceeds owner's balance");
        
        // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
        // decrementing then incrementing.
        unchecked{
            _balances[_from] = fromBalance - _value;
            _balances[_to] += _value;
        }

        emit Transfer(_from, _to, _value);

        _afterTokenTransfer(_from, _to, _value);


    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }
}