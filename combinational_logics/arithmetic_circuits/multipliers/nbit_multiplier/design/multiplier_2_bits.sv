`timescale 1ns/1ps
// Two bit multiplier design

module multiplier_2_bits(
    input  logic [1:0] a,
    input  logic [1:0] b,
    output logic [3:0] p
);
    
    // Inrermediate wires
    logic a0b0, a1b0, a0b1, a1b1; 
    logic c1, c2;

    // Intermediate Calculations
    assign a0b0 = a[0] & b[0];
    assign a1b0 = a[1] & b[0];
    assign a0b1 = a[0] & b[1];
    assign a1b1 = a[1] & b[1];
    assign c1 = a1b0 & a0b1;
    assign c2 = c1 & a1b1;

    // Output Assignment
    assign p[0] = a0b0;    
    assign p[1] = a0b1 ^ a1b0;      
    assign p[2] = a1b1 ^ c1;    
    assign p[3] = c2;    

endmodule




// -----------------------------------------------------------------------------------------------
//                                                                      -> product[0] = pp00
// -----------------------------------------------------------------------------------------------
// pp01   ADD pp10                -> half adder -> sum1_1 and carry1_1  -> product[1] = sum1_1
// -----------------------------------------------------------------------------------------------
// carry1_1 ADD pp02   ADD pp11   -> full adder -> sum2_1 and carry2_1
// carry2_1 ADD sum2_1 ADD pp20   -> full adder -> sum2_2 and carry2_2  -> product[2] = sum2_2
// -----------------------------------------------------------------------------------------------
// carry2_2 ADD pp03   ADD pp12   -> full adder -> sum3_1 and carry3_1
// carry3_1 ADD sum3_1 ADD pp21   -> full adder -> sum3_2 and carry3_2
// carry3_2 ADD sum3_2 ADD pp30   -> full adder -> sum3_3 and carry3_3  -> product[3] = sum3_3
// -----------------------------------------------------------------------------------------------
// carry3_3 ADD pp13   ADD pp22   -> full adder -> sum4_1 and carry4_1
// carry4_1 ADD sum4_1 ADD pp31   -> full adder -> sum4_2 and carry4_2  -> product[4] = sum4_2
// -----------------------------------------------------------------------------------------------
// carry4_2 ADD pp23   ADD pp32   -> full adder -> sum5_1 and carry5_1  -> product[5] = sum5_1
// -----------------------------------------------------------------------------------------------
// carry5_1 ADD pp33              -> half adder -> sum6_1 and carry6_1  -> product[6] = sum6_1
// -----------------------------------------------------------------------------------------------
//                                                                      -> product[7] = carry6_1
// -----------------------------------------------------------------------------------------------



