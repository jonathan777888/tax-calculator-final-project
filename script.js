document.addEventListener("DOMContentLoaded", function () {
  const incomeInput = document.getElementById("income");
  const button = document.getElementById("calculateBtn");
  const result = document.getElementById("result");

  button.addEventListener("click", function () {
    try {
      const tax = calculateTax(incomeInput.value);
      result.textContent = "Tax: " + formatCurrency(tax);
    } catch (error) {
      result.textContent = "Error: " + error.message;
    }
  });
});
