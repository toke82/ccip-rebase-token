1. A protocol that allows user to deposit into a vault and in return, receiver rebase tokens that represent their underlying balance.
2. Rebase token -> balanceOf function is dynamic to show the changin balance with time.
    - Balance increases linearly with time
    - mint tokens to our users every time they perform an action (minting, burning, transfering, or.... bridging)
3. Interes rate
    - Individually set an interes rate of each user base on some global interest rate of the protocol at the time the user deposits into the vault.
    - This global interest rate can only decrease to incetivise/reward early adopters.
    - Increase token adoption!. 