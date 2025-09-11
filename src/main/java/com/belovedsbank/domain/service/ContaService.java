package com.belovedsbank.domain.service;


import com.belovedsbank.domain.model.Conta;
import com.belovedsbank.domain.port.ContaRepositoryPort;
import com.belovedsbank.domain.port.ContaServicePort;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;

@Service
@RequiredArgsConstructor
public class ContaService implements ContaServicePort {

    private final ContaRepositoryPort contaRepository;

    @Override
    public Conta depositar(String numeroConta, BigDecimal valor) {
        if (valor.compareTo(BigDecimal.ZERO) <= 0) {
            throw new IllegalArgumentException("Valor do depósito deve ser maior que zero.");
        }
        Conta conta = contaRepository.findByNumeroConta(numeroConta)
                .orElseThrow(() -> new RuntimeException("Conta não encontrada."));
        conta.setSaldo(conta.getSaldo().add(valor));
        return contaRepository.save(conta);
    }

    @Override
    public Conta sacar(String numeroConta, BigDecimal valor) {
        if (valor.compareTo(BigDecimal.ZERO) <= 0) {
            throw new IllegalArgumentException("Valor do saque deve ser maior que zero.");
        }
        Conta conta = contaRepository.findByNumeroConta(numeroConta)
                .orElseThrow(() -> new RuntimeException("Conta não encontrada."));
        if (conta.getSaldo().compareTo(valor) < 0) {
            throw new IllegalArgumentException("Saldo insuficiente.");
        }
        conta.setSaldo(conta.getSaldo().subtract(valor));
        return contaRepository.save(conta);
    }


}
