package com.belovedsbank.domain.port;

import com.belovedsbank.domain.model.Conta;

import java.math.BigDecimal;

public interface ContaServicePort {
    Conta depositar(String numeroConta, BigDecimal valor);
    Conta sacar(String numeroConta, BigDecimal valor);
}
