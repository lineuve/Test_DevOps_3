#include <gtest/gtest.h>

#include "../src/calculator.hpp"

// Teste com Inteiros
TEST(TestCalculator, Integer) {
  Calculator<int> c(10, 2);
  EXPECT_EQ(c.add(), 12);
  EXPECT_EQ(c.subtract(), 8);
  EXPECT_EQ(c.multiply(), 20);
  EXPECT_EQ(c.divide(), 5);
}

// Teste com Decimais
TEST(TestCalculator, Double) {
  Calculator<double> c(10.5, 2.5);
  EXPECT_DOUBLE_EQ(c.add(), 13.0);
  EXPECT_DOUBLE_EQ(c.subtract(), 8.0);
  EXPECT_DOUBLE_EQ(c.multiply(), 26.25);
  EXPECT_DOUBLE_EQ(c.divide(), 4.2);
}

// Teste da Proteção (Divisão por Zero)
// Agora o teste SABE que deve dar erro e considera isso um SUCESSO
TEST(TestCalculator, DivisionByZero) {
  Calculator<int> c(10, 0);
  EXPECT_THROW(c.divide(), std::invalid_argument);
}
