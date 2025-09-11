package com.belovedsbank.domain.model;

import lombok.Data;

import javax.persistence.Entity;
import javax.persistence.Id;
import java.math.BigDecimal;

@Data
@Entity
public class Conta {

    @Id
    private String numeroConta;
    private BigDecimal saldo;

}
