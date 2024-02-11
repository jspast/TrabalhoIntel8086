; João Speranza Pastorello - 00580242

.model small
.stack
.data

;------------------------------------------
; CONSTANTES
;------------------------------------------

CR              equ	0Dh  	; Carriage Return (Enter)
LF              equ	0Ah  	; Line Feed ('\n')
TAB		equ	09h	; Tabulação

MAXCMD          equ	100	; Tamanho máximo da linha de comando
MAXARQ		equ	100	; Tamanho máximo do nome do arquivo

MAXFILE_BUF	equ	100	; Tamanho do buffer para leitura de arquivo
MAXLINHA_BUF    equ     100     ; Tamanho do buffer de linha do arquivo

MIN_TENSAO	equ	10	; O mínimo de tensão não considerado sem tensão

;------------------------------------------
; DADOS
;------------------------------------------

CMDLINE		db	MAXCMD dup(0)	; Buffer para armazenar a linha de comando

FILE_IN		db	"a.in",0	; Nome do arquivo de entrada padrão
		db 	MAXARQ dup(0)

FILE_OUT	db      "a.out",0	; Nome do arquivo de saída padrão
		db	MAXARQ dup(0)

TENSAO_STR	db	"127",0		; Tensão padrão em ASCII
TENSAO		db	0		; Tensão em inteiro

TENSAO_BUF_STR	db	4 dup(0)	; Buffer para armazenar a tensão lida do arquivo
TENSAO_BUF	db	0		; Buffer para tensão em inteiro

SEGUNDOS_STR	db	6 dup(0)	; contador de segundos em ASCII

SEGUNDOS	dw	0		; Contador de segundos (linhas do arquivo)
SEGUNDOS_Q	dw	0		; Contador de segundos de tensão com qualidade
SEGUNDOS_S	dw	0		; Contador de segundos sem tensão

HORA_BUF	db	0
MIN_BUF		db	0
SEG_BUF		db	0

TENSOES         db      0               ; Contador de número de tensões em uma linha
TENSOES_Q	db	0		; Contador de tensões com qualidade em uma linha
TENSOES_S	db	0		; Contador de tensões sem tensão em uma linha

LINHA_BUF	db	MAXLINHA_BUF dup (?)	; Buffer para armazenar linha do arquivo

ENTER		db	CR,LF,0		; String para pular linha

OPCAO		db	"Opcao [-",0
OPCAO2		db	" ] ",0
ERRO_OPCAO	db	" ] sem parametro",CR,LF,0	; Mensagem de erro para opção inválida

ERRO_TENSAO	db	"Parametro da opcao [-v] deve ser 127 ou 220",CR,LF,0	; Mensagem de erro para tensão inválida

ERRO_ARQUIVO	db	"Erro ao abrir arquivo",CR,LF,0	; Mensagem de erro para arquivo

ERRO_LINHA	db	"Linha ",0	; Mensagem de erro para linha inválida
ERRO_CONTEUDO	db	" invalido: ",0	; Mensagem de erro para conteúdo inválido

TEMPO		db	"Tempo total de medicoes: ",0
TEMPO_Q		db	"Tempo tensao de qualidade: ",0
TEMPO_S		db	"Tempo sem tensao: ",0

TEMPO_BUF	db	"  :  :  ",0

; Variáveis necessarias para funções.

sw_n	        dw	0			; Usada dentro da funcao sprintf_w
sw_f    	db	0			; Usada dentro da funcao sprintf_w
sw_m	        dw	0			; Usada dentro da funcao sprintf_w

FileBuffer	db	MAXFILE_BUF dup (?)	; Usada dentro do setChar e getChar

;------------------------------------------
; CÓDIGO
;------------------------------------------

.code
.startup

	; Obtém os argumentos da linha de comando

	CLD	; Limpa o direction flag

	; Salva linha de comando em CMDLINE

	push	ds      ; Salva as informações de segmentos
	push    es

	mov     ax,ds   ; Troca DS com ES para poder usa o REP MOVSB
	mov     bx,es
	mov     ds,bx
	mov     es,ax

	mov	si,80h	; Obtém o tamanho do string da linha de comando e coloca em CX
	mov	ch,0
	mov	cl,[si]

	mov	si,81h	; Inicializa o ponteiro de origem

	lea	di,CMDLINE	; Inicializa o ponteiro de destino

	rep	movsb

	pop 	es	; retorna as informações dos registradores de segmentos
	pop	ds
	mov     ax,ds
	mov     es,ax

	lea     si,CMDLINE

percorre_linha:
	
	call	percorre_str_espaco
	jc	fim_cmd

	mov	al,[si]
	inc	si

	cmp	al,0
	je	fim_cmd

	cmp	al,'-'
	je	verifica_opcao1

	jmp	percorre_linha

verifica_opcao1:

	; Verifica qual a opção depois do '-'

	mov	dl,[si]
	cmp	dl,'i'
	jne	verifica_opcao3
	lea	di,FILE_IN
	jmp	salva_opcao

verifica_opcao3:
	cmp	dl,'o'
	jne	verifica_opcao4
	lea	di,FILE_OUT
	jmp	salva_opcao

verifica_opcao4:
	cmp	dl,'v'
	je 	verifica_opcao5
	jmp	percorre_linha
	
verifica_opcao5:
	lea	di,TENSAO_STR
	
salva_opcao:

	; Verifica o parâmetro da opção

	call	percorre_str_espaco
	jc	erro_sem_parametro
	
	mov	al,[si]

	cmp	al,0
	je	erro_sem_parametro

	cmp	al,'-'
	je	erro_sem_parametro

	; Salva o parâmetro da opção

	call	strlen

	rep     movsb

	mov	byte ptr[di],0	; Coloca 0 no final da string

	jmp	percorre_linha

fim_cmd:

	; Converte tensão para inteiro

	lea	bx,TENSAO_STR
	call	atoi

	mov	TENSAO,al

	; Verifica valor da tensão

	cmp	ax,127
	je	tensao_ok

	cmp	ax,220
	jne	erro_v

tensao_ok:

	; Imprime os parâmetros considerados

	mov	al,'i'
	lea	cx,FILE_IN
	call	print_param

	mov	al,'o'
	lea	cx,FILE_OUT
	call	print_param

	mov	al,'v'
	lea	cx,TENSAO_STR
	call	print_param

	jmp	abre_arquivo

erro_sem_parametro:

	; Erro: opção sem parâmetro

	lea	di,ERRO_OPCAO

	mov	al,dl
	stosb

	lea	bx,OPCAO
	call    printf_s
	lea	bx,ERRO_OPCAO
	call    printf_s

	jmp	fim

erro_v:

	; Erro: valor da tensão inválido

	lea	bx,ERRO_TENSAO
	call    printf_s

	jmp	fim

abre_arquivo:

	; Abre o arquivo de entrada

	lea	dx,FILE_IN
	call	fopen
	jc	erro_abre_arquivo

	push	bx

	xor	cx,cx

	lea	di,LINHA_BUF

	jmp	processa_arquivo

erro_abre_arquivo:

	; Erro ao abrir arquivo

	lea	bx,ERRO_ARQUIVO
	call    printf_s

	jmp	fim

processa_arquivo:

	; Copia linha do arquivo para LINHA_BUF

	call	getChar
	jc	fim_arquivo

	cmp	dl,CR
	je	fim_linha

	cmp	dl,LF
	je	fim_linha

	mov	byte ptr[di],dl

	inc	di

	jmp	processa_arquivo

fim_linha:

	call	getChar
	jc	fim_arquivo

	cmp	dl,CR
	je	fim_linha

	cmp	dl,LF
	je	fim_linha

	mov	byte ptr[di],0

	inc	SEGUNDOS

verifica_fim_arquivo:

	; Verifica se a linha é "fim"

	lea	si,LINHA_BUF
	mov	dl,[si]

letra1:
	cmp	dl,'f'
	je	letra2
	
	cmp	dl,'F'
	je	letra2

	jmp	salva_tensoes

letra2:
	cmp	dl,'i'
	je	letra3
	
	cmp	dl,'I'
	je	letra3

	jmp	salva_tensoes

letra3:
	cmp	dl,'m'
	je	fim_arquivo
	
	cmp	dl,'M'
	je	fim_arquivo

	jmp	salva_tensoes

salva_tensoes:

	; Salva e verifica as tensões da linha

	mov	TENSOES,0
	mov	TENSOES_Q,0
	mov	TENSOES_S,0

	lea	si,LINHA_BUF

salva_tensao:

	; Salva e verifica uma tensão

	xor	cx,cx
	mov	TENSAO,cl

	jmp	tensao1

loop_tensao1:
	inc	si

tensao1:
	mov	dl,[si]

	cmp	dl,' '
	je	loop_tensao1

	cmp	dl,TAB
	je	loop_tensao1

	cmp	dl,0
	je	erro_leitura

	call	salva_dig_tensao

tensao2:
	inc	si
	mov	dl,[si]
	
	cmp	dl,','
	je	fim_tensao

	cmp	dl,' '
	je	tensao3

	cmp	dl,TAB
	je	tensao3

	cmp	dl,0
	je	fim_tensao

	call	salva_dig_tensao
	jc	erro_leitura

	jmp	tensao2

tensao3:
	inc	si
	mov	dl,[si]

	cmp	dl,','
	je	fim_tensao

	cmp	dl,' '
	je	tensao3

	cmp	dl,TAB
	je	tensao3

	cmp	dl,0
	je	fim_tensao

	jmp	erro_leitura

fim_tensao:

	lea	bx,TENSAO_BUF_STR

	call	verifica_tensao
	jc	erro_leitura

	inc	TENSOES
	cmp	TENSOES,4
	je	erro_leitura

	cmp	dl,0
	jne	processa_tensao

	cmp	TENSOES,2
	je	erro_leitura

processa_tensao:

	lea	bx,TENSAO_BUF_STR
	call	atoi
	mov	TENSAO_BUF,al

sem_tensao:

	cmp	al,MIN_TENSAO
        jae     qualidade_tensao

        inc     TENSOES_S

	jmp	sem_qualidade

qualidade_tensao:

        cmp	al,TENSAO-10
	jl	sem_qualidade

	cmp	al,TENSAO+10
	ja	sem_qualidade

	inc	TENSOES_Q

sem_qualidade:

	cmp	dl,0
	je	processa_arquivo

	jmp	salva_tensao

erro_leitura:

	lea	bx,ERRO_LINHA
	call	printf_s

	mov	ax,SEGUNDOS
	lea	bx,SEGUNDOS_STR
	call	sprintf_w
	lea	bx,SEGUNDOS_STR
	call	printf_s

	lea	bx,ERRO_CONTEUDO
	call	printf_s

	lea	bx,LINHA_BUF
	call	printf_s

	lea	bx,ENTER
	call	printf_s

	call	fim

fim_arquivo:

	; Fecha o arquivo

	pop	bx
	call	fclose

	; Imprime relatório na tela

	lea	bx,TEMPO
	call	printf_s

	mov	ax,SEGUNDOS
	call	formata_tempo

	lea	bx,TEMPO_BUF
	call	printf_s

	lea	bx,ENTER
	call	printf_s

fim:

.exit

;------------------------------------------
; FUNÇÕES
;------------------------------------------

; percorre_str_espaco: String (si) -> String (si) Boolean (CF)
; Obj.: Dada uma string, percorre a string até encontrar o primeiro caractere depois de um espaço
; Se encontrar, retorna o ponteiro para esse caractere e define CF como 0
; Se não encontrar, retorna o ponteiro para o final da string e define CF como 1
percorre_str_espaco	proc	near

	; Procura por um espaço

	mov	al,[si]
	inc	si

	cmp	al,' '
	je	p_str_1

	cmp	al,0
	je	p_str_e

p_str_1:

	; Procura por um caractere diferente de espaço

	mov	al,[si]
	inc	si

	cmp	al,' '
	je	p_str_1

	cmp	al,0
	je	p_str_e

	dec	si	; Ajusta o ponteiro para o primeiro caractere depois do espaço

	clc	; Define CF como 0
	ret

p_str_e:

	stc	; Define CF como 1
	ret

percorre_str_espaco	endp

; strlen: String (si) -> Inteiro (cx)
; Obj.: Dada uma string, retorna o tamanho da string (até espaço ou fim), sem alterar o ponteiro da string
strlen	proc	near

	; Inicializa o contador

	xor	cx,cx

	push	si

strlen_1:

	; Conta o tamanho da string

	mov	al,[si]
	inc	si

	cmp	al,' '
	je	fim_strlen

	cmp	al,0
	je	fim_strlen

	inc	cx
	jmp	strlen_1

fim_strlen:
	pop	si

	ret

strlen	endp

; print_param: Char (al) String (cx) -> void
; Obj.: Dado uma opção e uma parâmetro, escreve o parâmetro da opção na tela
print_param	proc	near

	lea	di,OPCAO2
	stosb
	lea	bx,OPCAO
	call	printf_s
	lea	bx,OPCAO2
	call	printf_s
	mov	bx,cx
	call	printf_s
	lea	bx,ENTER
	call	printf_s

	ret

print_param	endp

; salva_dig_tensao: Char (dl) Inteiro (cx) -> Boolean (CF)
; Obj.: Dado um dígito e um contador de dígitos, salva esse dígito no buffer da tensão e incrmenta o contador
; Se chegou em 4 dígitos, define CF como 1
; Se não chegou, define CF como 0
salva_dig_tensao	proc	near

	push	di

	mov	al,dl

	lea	di,TENSAO_BUF_STR
	add	di,cx
	stosb

	pop	di

	inc	cx

	cmp	cx,4
	jne	sdt_ret

	stc
	ret

sdt_ret:
	clc
	ret

salva_dig_tensao	endp

; verifica_tensao: String (bx) Inteiro (ch) -> Boolean (CF)
; Obj.: Dada uma string e seu tamanho, verifica se a string é menor ou igual a "499"
; Se for, define CF como 1
; Se não for, define CF como 0
verifica_tensao	proc	near

	push	dx

	cmp	cx,3
	jl	vt_ret

	mov	dl,[bx]
	cmp	dl,'5'
	je	vt_ret

	pop	dx

	clc
	ret

vt_ret:
	pop	dx

	stc
	ret

verifica_tensao	endp

; formata_tempo: Inteiro (ax) -> String (bx)
; Obj.: Dado o número de segundos, devolve o tempo formatado
formata_tempo	proc near

	mov	dl,60

	xor	cx,cx

	mov	SEG_BUF,al

	cmp	ax,60
	jl	tempo_seg

	sub	cx,3

calc_min:

	div	dl

	mov	MIN_BUF,al
	mov	SEG_BUF,ah

	cmp	al,60
	jl	tempo_min

	sub	cx,3

calc_hora:

	xor	ah,ah

	div	dl

	mov	HORA_BUF,al
	mov	MIN_BUF,ah

tempo_hora:

	add	cx,6

	lea	bx,TEMPO_BUF+6
	mov	al,HORA_BUF

	xor	ah,ah

	call	sprintf_w

tempo_min:

	add	cx,3

	lea	bx,TEMPO_BUF+3
	mov	al,MIN_BUF

	xor	ah,ah

	call	sprintf_w

tempo_seg:

	lea	bx,TEMPO_BUF
	mov	al,SEG_BUF

	xor	ah,ah

	call	sprintf_w

	mov	si,cx

	mov	[si+bx+1],0

	lea	bx,TEMPO_BUF

formata_tempo	endp

; atoi: String (bx) -> Inteiro (ax)
; Obj.: recebe uma string e transforma em um inteiro
atoi	proc near

	mov	ax,0		; A = 0;
		
atoi_2:
	cmp	byte ptr[bx],0	; while (*S!='\0') {
	jz	atoi_1

	mov	cx,10		;	A = 10 * A
	mul	cx

	mov	ch,0		;	A = A + *S - '0'
	mov	cl,[bx]
	add	ax,cx

	sub	ax,'0'		;	A = A - '0'

	inc	bx		;	++S
		
	jmp	atoi_2		;}

atoi_1:
	ret			; return A;

atoi	endp

; printf_s: String (bx) -> void
; Obj.: dado uma String, escreve a string na tela
printf_s	proc	near

	mov	dl,[bx]		; While (*s!='\0') {
	cmp	dl,0
	je	ps_1

	push	bx		;	putchar(*s)
	mov	ah,2
	int	21H
	pop	bx

	inc	bx		; 	++s;
		
	jmp	printf_s	; }
		
ps_1:
	ret			; return;
	
printf_s	endp

; sprintf_w: Inteiro (ax) String (bx) -> String (bx)
; Obj.: dado um numero e uma string, transforma o numero em ascii e salva na string dada, quase um itoa()
; Ex.:
; mov ax, 3141
; lea bx, String (em que String e db 10 dup (?)) (o dup e pra ele saber que e pra reservar 100 bytes e o (?) diz que pode deixar o lixo de memoria)
; call sprintf_w
; -> string recebe "3141",0
sprintf_w	proc	near

	mov	sw_n,ax		; void sprintf_w(char *string, WORD n) {

	mov	cx,5		; k=5;
	
	mov	sw_m,10000	; m=10000;
	
	mov	sw_f,0		; f=0;
	
sw_do:				; do {

	mov	dx,0		;	quociente = n / m : resto = n % m;	// Usar instrução DIV
	mov	ax,sw_n
	div	sw_m
	
				;	if (quociente || f) {
				;		*string++ = quociente+'0'
				;		f = 1;
				;	}
	cmp	al,0
	jne	sw_store
	cmp	sw_f,0
	je	sw_continue
sw_store:
	add	al,'0'
	mov	[bx],al
	inc	bx
	
	mov	sw_f,1
sw_continue:
	
	mov	sw_n,dx		;	n = resto;
	
	mov	dx,0		;	m = m/10;
	mov	ax,sw_m
	mov	bp,10
	div	bp
	mov	sw_m,ax
	
	dec	cx		;	--k;
	
	cmp	cx,0		; } while(k);
	jnz	sw_do

				; if (!f)
				;	*string++ = '0';
	cmp	sw_f,0
	jnz	sw_continua2
	mov	[bx],'0'
	inc	bx
sw_continua2:

	mov	byte ptr[bx],0	;	*string = '\0';
				; }
	ret			; return;
		
sprintf_w	endp

; fopen: String (dx) -> File* (bx) Boolean (CF)		(Passa o File* para o ax tambem, mas por algum motivo ele move pro bx)
; Obj.: Dado o caminho para um arquivo, devolve o ponteiro desse arquivo e define CF como 0 se o processo deu certo
; Ex.:
; lea dx, fileName		(em que fileName eh "temaDeCasa/feet/feet1.png",0) (Talvez a orientacao das barras varie com o sistema operacional, na duvida coloca tudo dentro de WORK pra poder usar so o nome do arquivo)
; call fopen
; -> bx recebe a imagem e CF (carry flag) nao ativa
; ou -> bx recebe lixo e CF ativa
fopen	proc	near

	mov	al,0
	mov	ah,3dh
	int	21h
	mov	bx,ax
	ret

fopen	endp

; fcreate: String (dx) -> File* (bx) Boolean (CF)
; Obj.: Dado o caminho para um arquivo, cria um novo arquivo com dado nome em tal caminho e devolve seu ponteiro, define CF como 0 se o processo deu certo
; Ex.:
; lea dx, fileName		(em que fileName eh "fatos/porQueChicoEhOMelhor.txt",0) (Talvez a orientacao das barras varie com o sistema operacional, na duvida coloca tudo dentro de WORK pra poder usar so o nome do arquivo)
; call fcreate
; -> bx recebe o txt e CF (carry flag) nao ativa
; ou -> bx recebe lixo e CF ativa
fcreate	proc	near

	mov	cx,0
	mov	ah,3ch
	int	21h
	mov	bx,ax
	ret

fcreate	endp

; fclose: File* (bx) -> Boolean (CF)
; Obj.: evitar um memory leak fechando o arquivo
; Ex.:
; mov bx, filePtr	(em que filePtr eh um ponteiro retornado por fopen/fcreate)
; call fclose
; -> Se deu certo, CF == 0
; (Recomendo zerar o filePtr pra voce nao fazer merda)
fclose	proc	near

	mov	ah,3eh
	int	21h
	ret

fclose	endp

; getChar: File* (bx) -> Char (dl) Inteiro (AX) Boolean (CF)
; Obj.: Dado um arquivo, devolve um caractere, a posicao do cursor e define CF como 0 se a leitura deu certo (diferente do getchar() do C, mais pra um getc(FILE*))
; Ex.:
; mov bx, filePtr	(em que filePtr eh um ponteiro retornado por fopen/fcreate)
; call getChar
; -> char em dl e cursor em AX se CF == 0
; senao, deu ruim
getChar	proc	near

	push	cx

	mov	ah,3fh
	mov	cx,1
	lea	dx,FileBuffer
	int	21h
	mov	dl,FileBuffer

	pop	cx

	ret

getChar	endp

; setChar: File* (bx) Char (dl) -> Inteiro (ax) Boolean (CF)
; Obj.: Dado um arquivo e um caractere, escreve esse caractere no arquivo e devolve a posicao do cursor e define CF como 0 se a leitura deu certo
; Ex.:
; mov bx, filePtr	(em que filePtr eh um ponteiro retornado por fopen/fcreate)
; call setChar
; -> posicao do cursor em AX e CF == 0 se deu certo
setChar	proc	near

	mov	ah,40h
	mov	cx,1
	mov	FileBuffer,dl
	lea	dx,FileBuffer
	int	21h
	ret

setChar	endp

end