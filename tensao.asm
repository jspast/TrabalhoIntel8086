; Jo„o Speranza Pastorello - 00580242

.model small
.stack
.data

;------------------------------------------
; CONSTANTES
;------------------------------------------

CR              equ	0Dh  	; Carriage Return (Enter)
LF              equ	0Ah  	; Line Feed ('\n')
MAXCMD          equ	100	; Tamanho m·ximo da linha de comando
MAXARQ		equ	100	; Tamanho m·ximo do nome do arquivo

;------------------------------------------
; DADOS
;------------------------------------------

CMDLINE		db	MAXCMD dup(0)	; Buffer para armazenar a linha de comando

FILE_IN		db	"a.in",0	; Nome do arquivo de entrada padr„o
		db 	MAXARQ dup(0)

FILE_OUT	db      "a.out",0	; Nome do arquivo de saÌda padr„o
		db	MAXARQ dup(0)

TENSAO_ASCII	db	"127",0		; Tens„o padr„o em ASCII

TENSAO		db	0		; Tens„o

ENTER		db	CR,LF,0		; String para pular linha

OPCAO		db	"Opcao [-",0
OPCAO2		db	" ] ",0
ERRO_OPCAO	db	" ] sem parametro",CR,LF,0	; Mensagem de erro para opÁ„o inv·lida

ERRO_TENSAO	db	"Parametro da opcao [-v] deve ser 127 ou 220",CR,LF,0	; Mensagem de erro para tens„o inv·lida

ERRO_ARQUIVO	db	"Erro ao abrir arquivo",CR,LF,0	; Mensagem de erro para arquivo

ERRO_LINHA	db	"Linha ",0	; Mensagem de erro para linha inv·lida
ERRO_CONTEUDO	db	"invalido: ",0	; Mensagem de erro para conte˙do inv·lido

;------------------------------------------
; C”DIGO
;------------------------------------------

; Variavel e constante necessarias para gets funcionar. Recomendo deletar elas e a gets e usar a ReadString no lugar.
MAXSTRING 	equ	200 			; Necessario para gets funcionar (loucura, eu sei), pode alterar o valor
String		db	MAXSTRING dup (?)	; Usado dentro da funcao gets. Sim, ela nao funciona sem. Sim, isso eh ma pratica.

sw_n	        dw	0			; Usada dentro da funcao sprintf_w
sw_f    	db	0			; Usada dentro da funcao sprintf_w
sw_m	        dw	0			; Usada dentro da funcao sprintf_w
FileBuffer	db	10 dup (?)		; Usada dentro do setChar e getChar

.code
.startup

; ObtÈm os argumentos da linha de comando

	CLD	; Limpa o direction flag

	; Salva linha de comando em CMDLINE

	push	ds      ; Salva as informaÁıes de segmentos
	push    es

	mov     ax,ds   ; Troca DS com ES para poder usa o REP MOVSB
	mov     bx,es
	mov     ds,bx
	mov     es,ax

	mov	si,80h	; ObtÈm o tamanho do string da linha de comando e coloca em CX
	mov	ch,0
	mov	cl,[si]

	mov	si,81h	; Inicializa o ponteiro de origem

	lea	di,CMDLINE	; Inicializa o ponteiro de destino

	rep	movsb

	pop 	es	; retorna as informaÁıes dos registradores de segmentos
	pop	ds
	mov     ax,ds
	mov     es,ax

	lea     si,CMDLINE

percorre_linha:
	
	call	percorre_str_espaco
	jc	fim_linha

	mov	al,[si]
	inc	si

	cmp	al,0
	je	fim_linha

	cmp	al,'-'
	je	verifica_opcao1

	jmp	percorre_linha

verifica_opcao1:

	; Verifica qual a opÁ„o depois do '-'

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
	lea	di,TENSAO_ASCII
	
salva_opcao:

	; Verifica o par‚metro da opÁ„o

	call	percorre_str_espaco
	jc	erro_sem_parametro
	
	mov	al,[si]

	cmp	al,0
	je	erro_sem_parametro

	cmp	al,'-'
	je	erro_sem_parametro

	; Salva o par‚metro da opÁ„o

	call	strlen

	rep     movsb

	mov	byte ptr[di],0	; Coloca 0 no final da string

	jmp	percorre_linha

fim_linha:

	; Converte tens„o para inteiro

	lea	bx,TENSAO_ASCII
	call	atoi

	mov	TENSAO,al

	; Verifica valor da tens„o

	cmp	ax,127
	je	tensao_ok

	cmp	ax,220
	jne	erro_v

tensao_ok:

	; Imprime os par‚metros considerados

	mov	al,'i'
	lea	cx,FILE_IN
	call	print_param

	mov	al,'o'
	lea	cx,FILE_OUT
	call	print_param

	mov	al,'v'
	lea	cx,TENSAO_ASCII
	call	print_param

	jmp	abre_arquivo

erro_sem_parametro:

	; Erro: opÁ„o sem par‚metro

	lea	di,ERRO_OPCAO

	mov	al,dl
	stosb

	lea	bx,OPCAO
	call    printf_s
	lea	bx,ERRO_OPCAO
	call    printf_s

	jmp	fim

erro_v:

	; Erro: valor da tens„o inv·lido

	lea	bx,ERRO_TENSAO
	call    printf_s

	jmp	fim

abre_arquivo:

	; Abre o arquivo de entrada

	lea	dx,FILE_IN
	call	fopen
	jc	erro_abre_arquivo

	jmp	fim

erro_abre_arquivo:

	lea	bx,ERRO_ARQUIVO
	call    printf_s

	jmp	fim

fim:

.exit

;------------------------------------------
; FUN«’ES
;------------------------------------------

; percorre_str_espaco: String (si) -> String (si) Boolean (CF)
; Obj.: Dada uma string, percorre a string atÈ encontrar o primeiro caractere depois de um espaÁo
; Se encontrar, retorna o ponteiro para esse caractere e define CF como 0
; Se n„o encontrar, retorna o ponteiro para o final da string e define CF como 1
percorre_str_espaco	proc	near

	; Procura por um espaÁo

	mov	al,[si]
	inc	si

	cmp	al,' '
	je	p_str_1

	cmp	al,0
	je	p_str_e

p_str_1:

	; Procura por um caractere diferente de espaÁo

	mov	al,[si]
	inc	si

	cmp	al,' '
	je	p_str_1

	cmp	al,0
	je	p_str_e

	dec	si	; Ajusta o ponteiro para o primeiro caractere depois do espaÁo

	clc	; Define CF como 0
	ret

p_str_e:

	stc	; Define CF como 1
	ret

percorre_str_espaco	endp

; strlen: String (si) -> Inteiro (cx)
; Obj.: Dada uma string, retorna o tamanho da string, sem alterar o ponteiro da string
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
; Obj.: Dado uma opÁ„o e uma par‚metro, escreve o par‚metro da opÁ„o na tela
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

	mov	dx,0		;	quociente = n / m : resto = n % m;	// Usar instruÁ„o DIV
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

	mov	ah,3fh
	mov	cx,1
	lea	dx,FileBuffer
	int	21h
	mov	dl,FileBuffer
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

; ReadString: String (bx) Inteiro (cx) -> void
; Obj.: dada uma string e um numero, pega input do teclado e guarda nessa string ate encontrar um enter ou ter pego o numero passado de caracteres
; Ex.:
; mov cx, 10        (vai pegar no maximo 10 caracteres)
; lea bx, buffer    (em que buffer e db 100 dup (?)) (o dup e pra ele saber que e pra reservar 100 bytes e o (?) diz que pode deixar o lixo de memoria)
; call ReadString   (Eu queria saber o que fez o Cechin decidir "Essa funcao aqui em especifico vai comecar com letra maiuscula")
; -> Ai o cara digita "Amo intel!" e ele quebra porque tem mais de 10 caracteres
; -> Ou ele digita "Amo Java!", enter, ai funciona e buffer fica com "Amo Java!",0 (sem o CR ou LF)
ReadString	proc	near

		;Pos = 0
		mov		dx,0

RDSTR_1:
		;while(1) { (while(1) deveria ser crime federal, o negocio e for(;;))
		;	al = Int21(7)		// Espera pelo teclado
		mov		ah,7
		int		21H

		;	if (al==CR) {
		cmp		al,0DH
		jne		RDSTR_A

		;		*S = '\0'
		mov		byte ptr[bx],0
		;		return
		ret
		;	}

RDSTR_A:
		;	if (al==BS) {
		cmp		al,08H
		jne		RDSTR_B

		;		if (Pos==0) continue;
		cmp		dx,0
		jz		RDSTR_1

		;		Print (BS, SPACE, BS)
		push	dx
		
		mov		dl,08H
		mov		ah,2
		int		21H
		
		mov		dl,' '
		mov		ah,2
		int		21H
		
		mov		dl,08H
		mov		ah,2
		int		21H
		
		pop		dx

		;		--s
		dec		bx
		;		++M
		inc		cx
		;		--Pos
		dec		dx
		
		;	}
		jmp		RDSTR_1

RDSTR_B:
		;	if (M==0) continue
		cmp		cx,0
		je		RDSTR_1

		;	if (al>=SPACE) {
		cmp		al,' '
		jl		RDSTR_1

		;		*S = al
		mov		[bx],al

		;		++S
		inc		bx
		;		--M
		dec		cx
		;		++Pos
		inc		dx

		;		Int21 (s, AL)
		push	dx
		mov		dl,al
		mov		ah,2
		int		21H
		pop		dx

		;	}
		;}
		jmp		RDSTR_1

ReadString	endp

; gets: String (bx) -> String (bx)
; Obj.: LÍ do teclado e coloca em em uma String no bx	(Honestamente recomendo deletar essa e usar o ReadString, essa funcao eh uma loucura)
; Ex.:
; lea bx, msgImportante		(em que msgImportante eh db 256 dup (?)) (o dup e pra ele saber que eh pra reservar 100 bytes e o (?) diz que pode deixar o lixo de memoria)
; call gets
; -> cara escreve "Adoro o Grellert" e mensagem vai para o BX e eh escrita na String passada, parece nao pegar Enter e \n
gets	proc	near
	push	bx

	mov		ah,0ah						; Lù uma linha do teclado
	lea		dx,String
	mov		byte ptr String, MAXSTRING-4	; 2 caracteres no inicio e um eventual CR LF no final
	int		21h

	lea		si,String+2					; Copia do buffer de teclado para o FileName
	pop		di
	mov		cl,String+1
	mov		ch,0
	mov		ax,ds						; Ajusta ES=DS para poder usar o MOVSB
	mov		es,ax
	rep 	movsb

	mov		byte ptr es:[di],0			; Coloca marca de fim de string
	ret
gets	endp

end