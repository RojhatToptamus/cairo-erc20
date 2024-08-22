use core::starknet::ContractAddress;

#[starknet::interface]
pub trait IERC20<TContractState> {
    fn total_supply(self: @TContractState) -> u256;
    fn name(self: @TContractState) -> felt252;
    fn symbol(self: @TContractState) -> felt252;
    fn decimals(self: @TContractState) -> u8;
    fn owner(self: @TContractState) -> ContractAddress;
    fn balance_of(self: @TContractState, address: ContractAddress) -> u256;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;
    fn transfer(ref self: TContractState, to: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        ref self: TContractState, from: ContractAddress, to: ContractAddress, amount: u256
    ) -> bool;
    fn mint(ref self: TContractState, to: ContractAddress, amount: u256) -> bool;
    fn burn(ref self: TContractState, from: ContractAddress, amount: u256) -> bool;
}


#[starknet::contract]
mod ERC20 {
    use core::starknet::{ContractAddress, get_caller_address};
    use core::starknet::storage::{
        Map, StoragePathEntry, StoragePointerWriteAccess, StoragePointerReadAccess
    };
    use core::num::traits::Zero;

    // ============================== Events ==============================
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Mint: Mint,
        Burn: Burn,
        Transfer: Transfer,
        Approve: Approve,
    }

    #[derive(Drop, starknet::Event)]
    struct Mint {
        #[key]
        to: ContractAddress,
        amount: u256,
    }
    #[derive(Drop, starknet::Event)]
    struct Burn {
        #[key]
        from: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct Transfer {
        #[key]
        from: ContractAddress,
        #[key]
        to: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct Approve {
        #[key]
        owner: ContractAddress,
        #[key]
        spender: ContractAddress,
        amount: u256,
    }

    // ============================== Errors ==============================
    mod Errors {
        pub const OWNER_ONLY: felt252 = 'ERC20: owner only';
        pub const APPROVE_TO_ZERO: felt252 = 'ERC20: approve to 0';
        pub const TRANSFER_FROM_ZERO: felt252 = 'ERC20: transfer from 0';
        pub const TRANSFER_TO_ZERO: felt252 = 'ERC20: transfer to 0';
        pub const MINT_TO_ZERO: felt252 = 'ERC20: mint to 0';
        pub const INSUFFICIENT_BALANCE: felt252 = 'ERC20: insufficient balance';
        pub const INSUFFICIENT_ALLOWANCE: felt252 = 'ERC20: insufficient allowance';
        pub const TOKEN_OWNER_ONLY: felt252 = 'ERC20: token owner only';
    }

    // ============================== Storage ==============================
    #[storage]
    struct Storage {
        name: felt252,
        symbol: felt252,
        decimals: u8,
        owner: ContractAddress,
        total_supply: u256,
        balances: Map<ContractAddress, u256>,
        allowances: Map<ContractAddress, Map<ContractAddress, u256>>,
    }

    // ============================== Constructor ==============================
    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: felt252,
        symbol: felt252,
        decimals: u8,
        owner: ContractAddress
    ) {
        self.name.write(name);
        self.symbol.write(symbol);
        self.decimals.write(decimals);
        self.owner.write(owner);
    }


    // ============================== Public Functions ==============================
    #[abi(embed_v0)]
    impl ERC20 of super::IERC20<ContractState> {
        fn total_supply(self: @ContractState) -> u256 {
            self.total_supply.read()
        }
        fn name(self: @ContractState) -> felt252 {
            self.name.read()
        }
        fn symbol(self: @ContractState) -> felt252 {
            self.symbol.read()
        }
        fn decimals(self: @ContractState) -> u8 {
            self.decimals.read()
        }

        fn owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
        }

        fn balance_of(self: @ContractState, address: ContractAddress) -> u256 {
            self.balances.entry(address).read()
        }
        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress
        ) -> u256 {
            self.allowances.entry(owner).entry(spender).read()
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();
            self._approve(caller, spender, amount);
            return true;
        }
        fn transfer(ref self: ContractState, to: ContractAddress, amount: u256) -> bool {
            let caller_address: ContractAddress = get_caller_address();
            self._transfer(caller_address, to, amount);
            return true;
        }
        fn transfer_from(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256
        ) -> bool {
            let caller_address: ContractAddress = get_caller_address();
            self._transfer_from(caller_address, from, to, amount);
            return true;
        }
        fn mint(ref self: ContractState, to: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();
            self._mint(caller, to, amount);
            return true;
        }
        fn burn(ref self: ContractState, from: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();
            self._burn(caller, from, amount);
            return true;
        }
    }

    // ============================== Internal Functions ==============================
    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _approve(
            ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256
        ) {
            assert(spender.is_non_zero(), Errors::APPROVE_TO_ZERO);

            self.allowances.entry(owner).entry(spender).write(amount);
            self.emit(Approve { owner: owner, spender: spender, amount: amount });
        }
        fn _transfer(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256
        ) {
            let caller_balance: u256 = self.balances.entry(from).read();

            assert(caller_balance >= amount, Errors::INSUFFICIENT_BALANCE);
            assert(to.is_non_zero(), Errors::TRANSFER_TO_ZERO);

            let recipient_balance: u256 = self.balances.entry(to).read();
            self.balances.entry(from).write(caller_balance - amount);
            self.balances.entry(to).write(recipient_balance + amount);
            self.emit(Transfer { from: from, to: to, amount: amount });
        }
        fn _transfer_from(
            ref self: ContractState,
            caller: ContractAddress,
            from: ContractAddress,
            to: ContractAddress,
            amount: u256
        ) {
            let current_allowance: u256 = self.allowances.entry(from).entry(caller).read();
            assert(current_allowance >= amount, Errors::INSUFFICIENT_ALLOWANCE);
            let updated_allowance: u256 = current_allowance - amount;
            self._approve(from, caller, updated_allowance);
            self._transfer(from, to, amount);
        }

        fn _mint(
            ref self: ContractState, caller: ContractAddress, to: ContractAddress, amount: u256
        ) {
            let owner_address: ContractAddress = self.owner.read();

            assert(caller == owner_address, Errors::OWNER_ONLY);
            assert(to.is_non_zero(), Errors::MINT_TO_ZERO);

            let recipient_balance: u256 = self.balances.entry(to).read();
            self.balances.entry(to).write(recipient_balance + amount);
            let total_supply: u256 = self.total_supply.read();
            self.total_supply.write(total_supply + amount);

            self.emit(Mint { to: to, amount: amount });
        }
        fn _burn(
            ref self: ContractState, caller: ContractAddress, from: ContractAddress, amount: u256
        ) {
            assert(caller == from, Errors::TOKEN_OWNER_ONLY);
            let from_balance: u256 = self.balances.entry(from).read();

            assert(from_balance >= amount, Errors::INSUFFICIENT_BALANCE);
            self.balances.entry(from).write(from_balance - amount);
            let total_supply: u256 = self.total_supply.read();
            self.total_supply.write(total_supply - amount);

            self.emit(Burn { from: from, amount: amount });
        }
    }
}
