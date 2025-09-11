package com.belovedsbank.domain.port;

import com.belovedsbank.domain.model.Conta;

import java.util.Optional;

public interface ContaRepositoryPort {

    Conta save(Conta conta);
    Optional<Conta> findByNumeroConta(String numeroConta);
}
