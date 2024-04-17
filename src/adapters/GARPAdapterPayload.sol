//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// GARP Adapter payload structure ***********************************************************************************************
// Note: Addresses have 65 bytes reserved, however, the first byte should only be used for the address size.
//
// Common Payload (beginning)
//    ESCROW_FLAGS          0   (1 byte)
//    + TOKEN_IDENTIFIER    1   (32 bytes)
//    + AMOUNT              33  (32 bytes)
//    + TO_ACCOUNT          65  (65 bytes)
//    + ESCROW_SCRATCHPAD   130 (32 bytes)
//    + RESERVED            164 (2 bytes)
//    
// 
// Common Payload (end)
//    + DATA_LENGTH         LENGTH-N-2 (2 bytes)
//    + DATA                LENGTH-N   (N bytes)



// Contexts *********************************************************************************************************************

bytes1 constant ESCROW_FLAG_MINT     = 0x01;  // 00000001
bytes1 constant ESCROW_FLAG_LOGIC    = 0x02;  // 00000010
// 00000100 through 10000000 are unused.

// Common Payload ***************************************************************************************************************

uint constant ESCROW_FLAGS           = 0;

uint constant TOKEN_IDENTIFIER_START = 1;
uint constant TOKEN_IDENTIFIER_END   = 33;

uint constant AMOUNT_START           = 33;
uint constant AMOUNT_END             = 65;

uint constant TO_ACCOUNT_LENGTH_POS = 65;
uint constant TO_ACCOUNT_START      = 66;
uint constant TO_ACCOUNT_START_EVM  = 110;  // If the address is an EVM address, this is the start
uint constant TO_ACCOUNT_END        = 130;

uint constant ESCROW_SCRATCHPAD_START = 196;
uint constant ESCROW_SCRATCHPAD_END   = 228;

uint constant CTX0_DATA_LENGTH_START     = 364;
uint constant CTX0_DATA_LENGTH_END       = 366;

uint constant CTX0_DATA_START            = 366;
