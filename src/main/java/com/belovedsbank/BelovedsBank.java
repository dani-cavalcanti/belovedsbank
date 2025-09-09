package com.belovedsbank;

public class BelovedsBank {

    private double balance;

    public BelovedsBank(double initialBalance) {
        this.balance = initialBalance;
    }

    public void deposit(double amount) {
        if (amount > 0) {
            balance += amount;
            System.out.println("Deposito de " + amount + " realizado. Saldo atual: " + balance);
        } else {
            System.err.println("Erro: O valor do deposito deve ser maior que zero.");
        }
    }

    public void withdraw(double amount) {
        if (amount < 0) {
            System.err.println("Erro: O valor do saque deve ser positivo.");
            return;
        }

        // Bug intencional
        if (amount > balance) {
            System.err.println("Erro critico de negocio: Saldo insuficiente para o saque de " + amount + ".");
            return;
        }
        balance -= amount;
        System.out.println("Saque de " + amount + " realizado. Saldo atual: " + balance);
    }
}