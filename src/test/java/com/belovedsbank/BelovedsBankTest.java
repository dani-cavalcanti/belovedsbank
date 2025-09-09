package com.belovedsbank;

import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Test;

public class BelovedsBankTest {

    @Test
    public void testWithdrawWithInsufficientFunds() {
        BelovedsBank account = new BelovedsBank(100.00);


        account.withdraw(200.00);


        Assertions.assertTrue(false, "O saque com saldo insuficiente deveria falhar.");
    }
}
