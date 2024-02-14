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

MAXCMD          equ	127	; Tamanho máximo da linha de comando
MAXARQ		equ	127	; Tamanho máximo do nome do arquivo

MAXFILE_BUF	equ	1	; Tamanho do buffer para leitura e escrita de arquivo
MAXLINHA_BUF    equ     1000	; Tamanho do buffer de linha do arquivo

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

SEGUNDOS_STR	db	6 dup(0)	; Contador de segundos em ASCII

SEGUNDOS	dw	0		; Contador de segundos (linhas do arquivo)
SEGUNDOS_Q	dw	0		; Contador de segundos de tensão com qualidade
SEGUNDOS_S	dw	0		; Contador de segundos sem tensão

TENSOES         db      0               ; Contador de número de tensões em uma linha
TENSOES_Q	db	0		; Contador de tensões com qualidade em uma linha
TENSOES_S	db	0		; Contador de tensões sem tensão em uma linha

LINHA_BUF	db	MAXLINHA_BUF dup (?)	; Buffer para armazenar linha do arquivo
DIG_1_BUF	db	0

ENTER		db	CR,LF,0		; String para pular linha

OPCAO		db	"Opcao [- ] ",0		; Mensagem de parâmetro de opção
ERRO_S_PARAM	db	"sem parametro",0

ERRO_TENSAO	db	"Parametro da opcao [-v] deve ser 127 ou 220",CR,LF,0	; Mensagem de erro para tensão inválida

ERRO_ARQUIVO	db	"Arquivo de entrada nao existente",CR,LF,0	; Mensagem de erro para arquivo

ERRO_LINHA	db	"Linha ",0	; Mensagem de erro para linha inválida
ERRO_CONTEUDO	db	" invalido: ",0	; Mensagem de erro para conteúdo inválido

ERRO		db	0	; Indicador de erro
ULT_LINHA       db      0	; Indicador de última linha do arquivo

TEMPO		db	"Tempo total de medicoes: ",0	; Mensagens de tempo de medição
TEMPO_Q		db	"Tempo de tensao adequada: ",0
TEMPO_S		db	"Tempo sem tensao: ",0

TEMPO_BUF	db	"        ",0	; Buffer para armazenar tempo formatado
TEMPO_FORMAT	db	"00:00:00",0	; Modelo de formatação de tempo

HORA_BUF	dw	0		; Buffers usados para formatação do tempo
MIN_BUF		dw	0
SEG_BUF		dw	0

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

	push	ds      ; Salva o segmento de dados

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

	pop	ds	; retorna as informações dos registradores de segmentos

	mov     ax,ds	; Faz ES apontar para o segmento de dados
	mov     es,ax

	lea     si,CMDLINE

percorre_cmd:

	; Procura por um '-' depois de um espaço
	
	call	percorre_str_espaco
	jc	fim_cmd

	cmp	al,0
	je	fim_cmd

	inc	si

	cmp	al,'-'
	je	v_op_i

	jmp	percorre_cmd

	; Verifica qual a opção depois do '-'

v_op_i:
	mov	dl,[si]
	cmp	dl,'i'
	jne	v_op_o
	lea	di,FILE_IN
	jmp	salva_opcao

v_op_o:
	cmp	dl,'o'
	jne	v_op_v
	lea	di,FILE_OUT
	jmp	salva_opcao

v_op_v:
	cmp	dl,'v'
	je 	op_v
	jmp	percorre_cmd
	
op_v:
	lea	di,TENSAO_STR
	
salva_opcao:

	; Verifica o parâmetro da opção

	call	percorre_str_espaco
	jc	erro_sem_parametro
	
	cmp	al,0
	je	erro_sem_parametro

	cmp	al,'-'
	je	erro_sem_parametro

	; Salva o parâmetro da opção

	call	strlen

	rep     movsb

	mov	byte ptr[di],0	; Coloca 0 no final da string

	jmp	percorre_cmd

fim_cmd:

	; Converte tensão para inteiro

	lea	bx,TENSAO_STR
	call	atoi

	mov	TENSAO,al

	; Verifica valor da tensão

	cmp	ax,127
	je	imprime_parametros

	cmp	ax,220
	jne	erro_v

imprime_parametros:

	; Imprime os parâmetros do relatório na tela

	mov	al,'i'
	lea	si,FILE_IN
	call	print_param

	mov	al,'o'
	lea	si,FILE_OUT
	call	print_param

	mov	al,'v'
	lea	si,TENSAO_STR
	call	print_param

	jmp	abre_arquivo

erro_sem_parametro:

	; Erro: opção sem parâmetro

	mov	al,dl

	lea	si,ERRO_S_PARAM
	call	print_param

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

	push	bx	; Guarda handle do arquivo

	xor	cx,cx

	lea	di,LINHA_BUF

	jmp	processa_arquivo

erro_abre_arquivo:

	; Erro ao abrir arquivo

	lea	bx,ERRO_ARQUIVO
	call    printf_s

	jmp	fim

processa_nova_linha:

	; Inicia processamento de nova linha

	pop     bx	; Recupera e guarda handle do arquivo
        push    bx

        lea	di,LINHA_BUF

	mov	al,DIG_1_BUF	; Salva primeiro caractere da linha lido ao acabar a linha anterior

	stosb

processa_arquivo:

	; Copia linha do arquivo para LINHA_BUF

	call	getChar
	jnc	nfim_arquivo1	; Testa se é o fim do arquivo

        inc     ULT_LINHA	; Se for, incrementa a variável de última linha

	jmp	fim_linha1

nfim_arquivo1:

	cmp	dl,CR
	je	fim_linha1

	cmp	dl,LF
	je	fim_linha1

	mov	byte ptr[di],dl		; Salva caractere se não for CR ou LF

	inc	di

	jmp	processa_arquivo

fim_linha1:

	; Testa próximos caracteres até realmente acabar a linha atual

	call	getChar
	jnc	nfim_arquivo2	; Testa se é o fim do arquivo

        inc     ULT_LINHA	; Se for, incrementa a variável de última linha
	
	jmp	fim_linha2

nfim_arquivo2:

	cmp	dl,CR
	je	fim_linha1

	cmp	dl,LF
	je	fim_linha1

	mov	DIG_1_BUF,dl	; Salva primeiro caractere da próxima linha

fim_linha2:
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
	inc	si
	mov	dl,[si]

	cmp	dl,'i'
	je	letra3
	
	cmp	dl,'I'
	je	letra3

	jmp	salva_tensoes

fim_arquivo3:

	; Trata caso de linha "fim"

	dec	SEGUNDOS
	inc     ULT_LINHA

	jmp	fecha_arquivo

letra3:
	inc	si
	mov	dl,[si]

	cmp	dl,'m'
	je	fim_arquivo3
	
	cmp	dl,'M'
	je	fim_arquivo3

salva_tensoes:

	; Salva e verifica as 3 tensões da linha

	mov	TENSOES,0	; Zera os contadores de tensões
	mov	TENSOES_Q,0
	mov	TENSOES_S,0

	lea	si,LINHA_BUF

salva_tensao:

	; Salva e verifica uma tensão

	xor	cx,cx		; Zera o contador de dígitos de uma tensão
	lea	di,TENSAO_BUF_STR	; Carrega posição inicial do buffer da tensão

	jmp	tensao1

loop_tensao1:
	inc	si

tensao1:

	; Salva primeiro dígito da tensão

	mov	al,[si]

	cmp	al,' '
	je	loop_tensao1

	cmp	al,TAB
	je	loop_tensao1

	cmp	al,0
	je	erro_leitura

	call	salva_dig_tensao

tensao2:

	; Salva segundo e terceiro dígitos da tensão

	inc	si
	mov	al,[si]
	
	cmp	al,','
	je	fim_tensao

	cmp	al,' '
	je	tensao3

	cmp	al,TAB
	je	tensao3

	cmp	al,0
	je	fim_tensao

	call	salva_dig_tensao
	jc	erro_leitura		; Se chegou em 4 dígitos, erro

	jmp	tensao2

tensao3:

	; Verifica caso de espaço entre dígitos da tensão

	inc	si
	mov	al,[si]

	cmp	al,','
	je	fim_tensao

	cmp	al,' '
	je	tensao3

	cmp	al,TAB
	je	tensao3

	cmp	al,0
	je	fim_tensao

	jmp	erro_leitura

fim_tensao:

	; Verifica tensões

	lea	bx,TENSAO_BUF_STR

	call	verifica_tensao		; Verifica se a última salva é menor que "500"
	jc	erro_leitura

	inc	TENSOES			; Verifica se essa é a quarta a ser salva (erro)
	cmp	TENSOES,4
	je	erro_leitura

	mov	dl,al	; Salva último dígito em dl

	cmp	dl,0
	jne	processa_tensao

	cmp	TENSOES,2		; Se é a última tensão da linha, verifica se tem menos de 3 (erro)
	jbe	erro_leitura

processa_tensao:

	; Salva tensão como inteiro

	lea	bx,TENSAO_BUF_STR
	push	dx
	call	atoi
	pop	dx
	mov	TENSAO_BUF,al

sem_tensao:

	; Verifica se é sem tensão

	cmp	al,MIN_TENSAO
        jae     qualidade_tensao

        inc     TENSOES_S

	jmp	fim_processa_tensao	; Se for, já se sabe que não tem qualidade

qualidade_tensao:

	; Verifica se tem qualidade

	mov	ah,TENSAO	; Teste -10
	sub	ah,10

        cmp	al,ah
	jb	fim_processa_tensao

	add	ah,20		; Teste +10

	cmp	al,ah
	ja	fim_processa_tensao

	inc	TENSOES_Q

fim_processa_tensao:

	; Verifica se é a última tensão da linha

	cmp	dl,0
	je	calc_tensoes

        inc     si
	jmp	salva_tensao	; Se não for, calcula a próxima

calc_tensoes:

	; Processa a linha como um todo

	cmp	TENSOES_S,3	; Verifica se é sem tensão
	jne	c_tensoes

	inc	SEGUNDOS_S
	jmp	fim_calc_tensoes	; Se for, já se sabe que não tem qualidade

c_tensoes:

	cmp	TENSOES_Q,3	; Verifica se tem qualidade
	jne	fim_calc_tensoes

	inc	SEGUNDOS_Q

fim_calc_tensoes:

	; Verifica se é a última linha do arquivo

        cmp     ULT_LINHA,0
        jne     ultima_linha

	jmp	processa_nova_linha	; Se não for, processa próxima linha

ultima_linha:
	jmp	fecha_arquivo		; Se for, fecha o arquivo

erro_leitura:

	; Imprime erro de linha inválida do arquivo

	inc	ERRO

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

	cmp	ULT_LINHA,0	; Se for a última linha, fecha o arquivo
	jne	fecha_arquivo

	jmp	processa_nova_linha	; Se não, vê se tem outras linhas inválidas

fecha_arquivo:

	; Fecha o arquivo

	pop	bx
	call	fclose

	cmp	ERRO,0		; Se houve erro no arquivo, encerra
	jne	fim

relatorio_tela:

	; Imprime medições do relatório na tela

	lea	bx,TEMPO
	call	printf_s

	mov	ax,SEGUNDOS
	call	formata_tempo
	mov	bx,si
	call	printf_s

	lea	bx,ENTER
	call	printf_s

relatorio_arquivo:

	; Imprime os parâmetros do relatório no arquivo

	lea     dx,FILE_OUT
        call    fcreate

	mov	al,'i'
	lea	dx,FILE_IN
	call	fprint_param

	mov	al,'o'
	lea	dx,FILE_OUT
	call	fprint_param

	mov	al,'v'
	lea	dx,TENSAO_STR
	call	fprint_param

	; Imprime medições do relatório no arquivo

        lea	si,TEMPO
	mov	ax,SEGUNDOS
	call	fprint_tempo

	lea	si,TEMPO_Q
	mov	ax,SEGUNDOS_Q
	call	fprint_tempo

	lea	si,TEMPO_S
	mov	ax,SEGUNDOS_S
	call	fprint_tempo

fim:

.exit

;------------------------------------------
; FUNÇÕES
;------------------------------------------

; percorre_str_espaco: String (si) -> String (si) Inteiro (ah) Inteiro (al) Boolean (CF)
; Obj.: Dada uma string, percorre a string até encontrar o primeiro caractere depois de um espaço
; Se encontrar, retorna o ponteiro para esse caractere e define CF como 0
; Se não encontrar, retorna o ponteiro para o final da string e define CF como 1
; Devolve em AH o número de espaços percorridos
; Devolve em AL o caractere encontrado
percorre_str_espaco	proc	near

	xor	ah,ah

	jmp	p_str_1

	; Procura por um espaço e depois por um caractere diferente de espaço

p_str_2:
	inc	ah

p_str_1:

	mov	al,[si]
	inc	si

	cmp	al,' '
	je	p_str_2

	cmp	al,0
	je	p_str_e

	cmp	ah,0
	je	p_str_1

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

; msg_param: Char (al) -> String (di)
; Obj.: Dado uma opção x, devolve a mensagem de opção "Opcao [-x]"
msg_param	proc	near

	lea	di,OPCAO+8
	stosb

	lea	di,OPCAO
	ret

msg_param	endp

; print_param: Char (al) String (si) -> void
; Obj.: Dado uma opção e um parâmtro, imprime a mensagem de parâmetro
print_param	proc	near

	call	msg_param

	mov	bx,di
	call	printf_s

	mov	bx,si
	call	printf_s

	lea	bx,ENTER
	call	printf_s

	ret

print_param	endp

; fprint_param: File* (bx) Char (al) String (dx) -> void
; Obj.: Dado um arquivo, uma opção e um parâmtro, imprime a mensagem de parâmetro
fprint_param	proc	near

	push	dx

	call	msg_param

	mov	si,di
	call	fprintf

	pop	si
	call	fprintf

	lea	si,ENTER
	call	fprintf

	ret

fprint_param	endp

; salva_dig_tensao: Char (al) String (di) Inteiro (cx) -> String (di) Boolean (CF)
; Obj.: Dado um dígito, uma string e um contador de dígitos, salva esse dígito na string e incrmenta o contador
; Se chegou em 4 dígitos, define CF como 1
; Se não chegou, define CF como 0
salva_dig_tensao	proc	near

	stosb

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
; Obj.: Dada uma string e seu tamanho (<= 3), verifica se a string é menor ou igual a "499"
; Se for, define CF como 0
; Se não for, define CF como 1
verifica_tensao	proc	near

	cmp	cx,3
	jb	vt_ret

	mov	dl,[bx]
	cmp	dl,'5'
	jb	vt_ret

	stc
	ret

vt_ret:
	clc
	ret

verifica_tensao	endp

; formata_tempo: Inteiro (ax) -> String (si)
; Obj.: Dado o número de segundos, devolve o tempo formatado a partir do primeiro número significativo
formata_tempo	proc near

	lea	di,TEMPO_BUF		; Copia modelo de formatação de tempo ("00:00:00",0) para a string
	lea	si,TEMPO_FORMAT
	mov	cx,9
	rep	movsb

	cmp	ax,60		; Verifica se é menor que 60 segundos
	jb	comec_seg	; Se for, já exibe começando pelos segundos

calc_min:

	; Se for maior ou igual a 60 segundos, calcula minutos

	call	div_60

	mov	SEG_BUF,dx

	cmp	ax,60
	jb	comec_min	; Se for menor que 60 minutos, já exibe começando pelos minutos

calc_hora:

	; Se for maior ou igual a 60 minutos, calcula horas

	call	div_60

	mov	HORA_BUF,ax
	mov	MIN_BUF,dx

tempo_hora:

	; Exibe horas

	xor	dx,dx

	cmp	ax,10		; Se for maior ou igual a 10, exibe 2 dígitos
	jae	hora_2_dig

	inc	cx	; Se não for, incrementa o posição de início

hora_2_dig:

	mov	bx,di	; Calcula ponteiro de destino
	add	bx,cx

	xor	ah,ah

	push	cx
	call	sprintf_w
	pop	cx

	mov	byte ptr [bx],":"	; Adiciona ':' depois das horas

	jmp     tempo_min

comec_min:
	mov	MIN_BUF,ax
	mov	cx,3		; Se começa em minutos, atualiza posição de início

tempo_min:

	; Exibe minutos

	xor	dx,dx

	mov	ax,MIN_BUF
	cmp	ax,10
	jae	min_2_dig

        cmp     cx,3	; Se minuto ocupar 1 dígito e for o primeiro significativo
        jne     n_comec_min
	inc	cx	; Incrementa posição de início

n_comec_min:
	inc	dx

min_2_dig:
	mov	bx,di	; Calcula ponteiro de destino
	add	bx,dx
	add	bx,3

	xor	ah,ah
	xor	dx,dx

	push	cx
	call	sprintf_w
	pop	cx

	mov	byte ptr [bx],":"

        jmp     tempo_seg

comec_seg:
	mov	SEG_BUF,ax
	mov	cx,6

tempo_seg:

	; Exibe segundos

	xor	dx,dx

	mov	ax,SEG_BUF
	cmp	ax,10
	jae	seg_2_dig

        cmp     cx,6
        jne     n_comec_seg
	inc	cx

n_comec_seg:
	inc	dx

seg_2_dig:
	mov	bx,di
	add	bx,dx
	add	bx,6

	xor	ah,ah
	xor	dx,dx

	push	cx
	call	sprintf_w
	pop	cx

	add	di,cx	; Calcula retorno com base na posição de início
	mov	si,di	; Para devolver o tempo formatado a partir do primeiro número significativo

	ret

formata_tempo	endp

; div_60: Inteiro (ax) -> Inteiro (ax) Inteiro (dx)
; Obj.: Dado um número, divide por 60 e devolve o quociente em ax e o resto em dx
div_60	proc	near

	xor	dx,dx
	mov	cx,60
	div	cx
	xor	cx,cx

	ret

div_60	endp

; fprint_tempo: File* (bx) Inteiro (ax) String (si) -> void
; Obj.: Dado um arquivo, um número de segundos e uma string, imprime a string com o tempo formatado
fprint_tempo	proc	near

	push	ax
	call	fprintf
	pop	ax

	push	bx
	call	formata_tempo
	pop	bx
	call	fprintf

	lea	si,ENTER
	call	fprintf

	ret

fprint_tempo	endp

; fprintf: File* (bx) String (si) -> void
; Obj.: Dado um arquivo e uma string, escreve a string no arquivo
fprintf proc    near

        mov     dl,[si]

        cmp     dl,0
        je      fim_fprintf

        inc     si

        call    setChar

        jmp     fprintf

fim_fprintf:

        ret

fprintf endp

; Funções elaboradas a partir de exemplos no moodle:

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
; Obj.: dado um numero e uma string, transforma o numero em ascii e salva na string dada, adicionando '\0' no final
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

; fopen: String (dx) -> File* (bx) Boolean (CF)
; Obj.: Dado o caminho para um arquivo, devolve o ponteiro desse arquivo e define CF como 0 se o processo deu certo
fopen	proc	near

	mov	al,0
	mov	ah,3dh
	int	21h
	mov	bx,ax
	ret

fopen	endp

; fcreate: String (dx) -> File* (bx) Boolean (CF)
; Obj.: Dado o caminho para um arquivo, cria um novo arquivo com dado nome em tal caminho e devolve seu ponteiro, define CF como 0 se o processo deu certo
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
fclose	proc	near

	mov	ah,3eh
	int	21h
	ret

fclose	endp

; getChar: File* (bx) -> Char (dl) Inteiro (AX) Boolean (CF)
; Obj.: Dado um arquivo, devolve um caractere, a posicao do cursor e define CF como 0 se a leitura deu certo
getChar	proc	near

	push	cx

	mov	ah,3fh
	mov	cx,1
	lea	dx,FileBuffer
	int	21h
	mov	dl,FileBuffer

	pop	cx

	cmp	ax,0
	je	erro_getchar

        clc
	ret

erro_getchar:

	stc
	ret

getChar	endp

; setChar: File* (bx) Char (dl) -> Inteiro (ax)
; Obj.: Dado um arquivo e um caractere, escreve esse caractere no arquivo e devolve a posicao do cursor
setChar	proc	near

	mov	ah,40h
	mov	cx,1
	mov	FileBuffer,dl
	lea	dx,FileBuffer
	int	21h
	ret

setChar	endp

end