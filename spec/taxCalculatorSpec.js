const { calculateTax, formatCurrency } = require("../taxCalculator");

describe("Tax Calculator", function () {
  it("returns 0 tax for zero income", function () {
    expect(calculateTax(0)).toBe(0);
  });

  it("returns 0 tax for negative income", function () {
    expect(calculateTax(-100)).toBe(0);
  });

  it("calculates 10 percent tax for income up to 10000", function () {
    expect(calculateTax(10000)).toBe(1000);
  });

  it("calculates tax for the second bracket", function () {
    expect(calculateTax(20000)).toBe(3000);
  });

  it("calculates tax at the top of the second bracket", function () {
    expect(calculateTax(50000)).toBe(9000);
  });

  it("calculates tax for income above 50000", function () {
    expect(calculateTax(60000)).toBe(12000);
  });

  it("formats currency correctly", function () {
    expect(formatCurrency(12000)).toBe("$12000.00");
  });
});
