package com.belovedsbank.application.service;


import com.belovedsbank.domain.model.Conta;
import com.belovedsbank.domain.port.ContaRepositoryPort;
import com.belovedsbank.domain.service.ContaService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class ContaServiceTest {

    @Mock
    private ContaRepositoryPort contaRepositoryPort;

    @InjectMocks
    private ContaService contaService;

    private Conta conta;

    @BeforeEach
    void setup() {
        conta = new Conta();
        conta.setNumeroConta("12345");
        conta.setSaldo(new BigDecimal("100.00"));
    }

    @Test
    void depositar_deveAumentarSaldo_quandoValorValido() {
        // Arrange
        BigDecimal valorDeposito = new BigDecimal("50.00");
        when(contaRepositoryPort.findByNumeroConta(anyString())).thenReturn(Optional.of(conta));
        when(contaRepositoryPort.save(any(Conta.class))).thenAnswer(i -> i.getArguments()[0]);

        // Act
        Conta contaAtualizada = contaService.depositar(conta.getNumeroConta(), valorDeposito);

        // Assert
        assertNotNull(contaAtualizada);
        assertEquals(new BigDecimal("150.00"), contaAtualizada.getSaldo());
        verify(contaRepositoryPort, times(1)).findByNumeroConta(anyString());
        verify(contaRepositoryPort, times(1)).save(any(Conta.class));
    }

    @Test
    void depositar_deveLancarExcecao_quandoValorInvalido() {
        // Arrange
        BigDecimal valorDeposito = new BigDecimal("-10.00");

        // Act & Assert
        IllegalArgumentException thrown = assertThrows(IllegalArgumentException.class, () -> {
            contaService.depositar(conta.getNumeroConta(), valorDeposito);
        });

        assertEquals("Valor do depósito deve ser maior que zero.", thrown.getMessage());
        verify(contaRepositoryPort, never()).save(any(Conta.class));
    }
}
