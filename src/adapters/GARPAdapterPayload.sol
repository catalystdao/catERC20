//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// GARP Adapter payload structure ***********************************************************************************************
// Note: Addresses have 65 bytes reserved, however, the first byte should only be used for the address size.
//
// Common Payload (beginning)
//    ESCROW_FLAGS                      0   (1 byte)
//    + SOURCE_TOKEN_IDENTIFIER         1   (32 bytes)
//    + DESTINATION_TOKEN_IDENTIFIER    33  (32 bytes)
//    + AMOUNT                          65  (32 bytes)
//    + TO_ACCOUNT                      97  (65 bytes)
//    + ESCROW_SCRATCHPAD               162 (32 bytes)
//    + RESERVED                        194 (2 bytes)
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

uint constant ESCROW_FLAGS                          = 0;

uint constant SOURCE_TOKEN_IDENTIFIER_START         = 1;
uint constant SOURCE_TOKEN_IDENTIFIER_START_EVM     = 13;
uint constant SOURCE_TOKEN_IDENTIFIER_END           = 33;

uint constant DESTINATION_TOKEN_IDENTIFIER_START    = 1;
uint constant DESTINATION_TOKEN_IDENTIFIER_START_EVM= 45;
uint constant DESTINATION_TOKEN_IDENTIFIER_END      = 65;

uint constant AMOUNT_START                          = 65;
uint constant AMOUNT_END                            = 97;

uint constant TO_ACCOUNT_LENGTH_POS                 = 97;
uint constant TO_ACCOUNT_START                      = 98;
uint constant TO_ACCOUNT_START_EVM                  = 142;  // If the address is an EVM address, this is the start
uint constant TO_ACCOUNT_END                        = 162;

uint constant ESCROW_SCRATCHPAD_START               = 162;
uint constant ESCROW_SCRATCHPAD_END                 = 194;

uint constant DATA_LENGTH_START                     = 194;
uint constant DATA_LENGTH_END                       = 196;

uint constant DATA_START                            = 196;
