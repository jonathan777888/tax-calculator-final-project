function calculateTax(income) {
  const amount = Number(income);

  if (Number.isNaN(amount)) {
    throw new Error("Income must be a number");
  }

  if (amount <= 0) {
    return 0;
  }

  if (amount <= 10000) {
    return amount * 0.10;
  }

  if (amount <= 50000) {
    return 1000 + (amount - 10000) * 0.20;
  }

  return 9000 + (amount - 50000) * 0.30;
}

function formatCurrency(value) {
  return "$" + Number(value).toFixed(2);
}

if (typeof module !== "undefined") {
  module.exports = {
    calculateTax,
    formatCurrency
  };
}

if (typeof window !== "undefined") {
  window.calculateTax = calculateTax;
  window.formatCurrency = formatCurrency;
}
