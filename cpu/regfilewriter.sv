// Writes back the result of executor to the regfile
// Responsibilities:
// - Updates the PC register with value from executor
// - Stores result of executor into the indicated register in regfile

module regfilewriter(
        input wire clk,
        input wire nreset,
        input logic enable,
        output logic ready
    );
endmodule
