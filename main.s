.data
az_n:   .asciiz "n: "
az_e:   .asciiz "e: "
az_m:   .asciiz "m: "
az_c:   .asciiz "c: "
az_nl:  .asciiz "\n"

.text
main:
        jal     rsa_init
        
        la      $a0, az_n
        jal     print_string
        jal     rsa_get_n
        move    $s0, $v0
        move    $a0, $v0
        jal     print_integer
        la      $a0, az_nl
        jal     print_string
        
        la      $a0, az_e
        jal     print_string
        jal     rsa_get_e
        move    $s1, $v0
        move    $a0, $v0
        jal     print_integer
        la      $a0, az_nl
        jal     print_string
        
        la      $a0, az_m
        jal     print_string
        li      $v0, 5
        syscall
        move    $s2, $v0
        
        la      $a0, az_c
        jal     print_string
        move    $a0, $s2
        move    $a1, $s0
        move    $a2, $s1
        jal     rsa_encrypt
        move    $s3, $v0
        move    $a0, $v0
        jal     print_integer
        la      $a0, az_nl
        jal     print_string
        
        la      $a0, az_m
        jal     print_string
        move    $a0, $s3
        jal     rsa_decrypt
        move    $a0, $v0
        jal     print_integer
        la      $a0, az_nl
        jal     print_string
        
        jal     rsa_clear
        
        li      $v0, 10
        syscall

print_string:
        li      $v0, 4
        syscall
        jr      $ra

print_integer:
        li      $v0, 1
        syscall
        jr      $ra
