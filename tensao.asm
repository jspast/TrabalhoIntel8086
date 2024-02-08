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
FILE_IN		db      MAXARQ dup(0)   ;"a.in",0
FILE_OUT	db      MAXARQ dup(0)	;"a.out",0	
TENSAO		db      MAXARQ dup(0)	;"127",0

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
	mov	ax,cx	; Salva o tamanho do string em AX, para uso futuro

	mov	si,81h	; Inicializa o ponteiro de origem

	lea	di,CMDLINE	; Inicializa o ponteiro de destino

	rep	movsb

	mov	cx,ax

	pop 	es	; retorna as informaÁıes dos registradores de segmentos
	pop	ds
	mov     ax,ds
	mov     es,ax

	; ObtÈm os argumentos da linha de comando

	;lea	si,CMDLINE
	lea     di,CMDLINE

	lea	bx,[di]

percorre_linha:
	mov	al,' '	; Procura por um espaÁo
	repne	scasb
	cmp     cx, 0
	je	fim_linha
	repe	scasb	; Vai atÈ o ˙ltimo espaÁo
	cmp     cx, 0
	je	fim_linha
	dec	di	; Ajusta o ponteiro para depois do ˙ltimo espaÁo
	inc	cx	
	

	mov	al,'-'	; Verifica se tem um '-' depois do espaÁo
	scasb
	je	verifica_opcao1
	loop	percorre_linha
	cmp     cx, 0
	je	fim_linha

verifica_opcao1:

	; Verifica qual a opÁ„o depois do '-'

	mov	dl,[di]
	cmp	dl,'i'
	jne	verifica_opcao3
	mov     si,di
	lea	di,FILE_IN
	jmp	salva_opcao
verifica_opcao3:
	cmp	dl,'o'
	jne	verifica_opcao4
	mov     si,di
	lea	di,FILE_OUT
	jmp	salva_opcao
verifica_opcao4:
	cmp	dl,'v'
	je 	verifica_opcao5
	mov     si,di
	loop	percorre_linha
	jmp	fim_linha
verifica_opcao5:
	lea	di,TENSAO
	
salva_opcao:
	;call	guarda_nome
	mov	ax,cx	; Salva o tamanho do string em AX, para uso futuro
	rep     movsb
	mov	cx,ax
	lea	bx,FILE_IN
	call    printf_s

	loop	percorre_linha
	jmp	fim_linha

fim_linha:
	

.exit

;------------------------------------------
; FUN«’ES
;------------------------------------------

; guarda_nome: String (bx) -> String (di)
; Obj.: Dada uma string, guarda o nome do arquivo na string
guarda_nome	proc	near
	
	rep     movsb
	lea	bx,FILE_IN
	call    printf_s

	ret
guarda_nome	endp

; atoi: String (bx) -> Inteiro (ax)
; Obj.: recebe uma string e transforma em um inteiro
; Ex:
; lea bx, String1 (Em que String1 È db "2024",0)
; call atoi
; -> devolve o numero 2024 em ax
atoi	proc near

		; A = 0;
		mov		ax,0
		
atoi_2:
		; while (*S!='\0') {
		cmp		byte ptr[bx], 0
		jz		atoi_1

		; 	A = 10 * A
		mov		cx,10
		mul		cx

		; 	A = A + *S
		mov		ch,0
		mov		cl,[bx]
		add		ax,cx

		; 	A = A - '0'
		sub		ax,'0'

		; 	++S
		inc		bx
		
		;}
		jmp		atoi_2

atoi_1:
		; return
		ret

atoi	endp

; printf_s: String (bx) -> void
; Obj.: dado uma String, escreve a string na tela
; Ex.:
; lea bx, String1 (em que String 1 È db "Java melhor linguagem",CR,LF,0)
; call printf_s
; -> Imprime o fato na tela e quebra linha
; (Nao sei o que acontece se colocar so o LF ou so o CR, da uma
; brincada ai pra descobrir)
printf_s	proc	near

;	While (*s!='\0') {
	mov		dl,[bx]
	cmp		dl,0
	je		ps_1

;		putchar(*s)
	push	bx
	mov		ah,2
	int		21H
	pop		bx

;		++s;
	inc		bx
		
;	}
	jmp		printf_s
		
ps_1:
	ret
	
printf_s	endp

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

; sprintf_w: Inteiro (ax) String (bx) -> void
; Obj.: dado um numero e uma string, transforma o numero em ascii e salva na string dada, quase um itoa()
; Ex.:
; mov ax, 3141
; lea bx, String (em que String e db 10 dup (?)) (o dup e pra ele saber que e pra reservar 100 bytes e o (?) diz que pode deixar o lixo de memoria)
; call sprintf_w
; -> string recebe "3141",0
sprintf_w	proc	near

;void sprintf_w(char *string, WORD n) {
	mov		sw_n,ax

;	k=5;
	mov		cx,5
	
;	m=10000;
	mov		sw_m,10000
	
;	f=0;
	mov		sw_f,0
	
;	do {
sw_do:

;		quociente = n / m : resto = n % m;	// Usar instruùùo DIV
	mov		dx,0
	mov		ax,sw_n
	div		sw_m
	
;		if (quociente || f) {
;			*string++ = quociente+'0'
;			f = 1;
;		}
	cmp		al,0
	jne		sw_store
	cmp		sw_f,0
	je		sw_continue
sw_store:
	add		al,'0'
	mov		[bx],al
	inc		bx
	
	mov		sw_f,1
sw_continue:
	
;		n = resto;
	mov		sw_n,dx
	
;		m = m/10;
	mov		dx,0
	mov		ax,sw_m
	mov		bp,10
	div		bp
	mov		sw_m,ax
	
;		--k;
	dec		cx
	
;	} while(k);
	cmp		cx,0
	jnz		sw_do

;	if (!f)
;		*string++ = '0';
	cmp		sw_f,0
	jnz		sw_continua2
	mov		[bx],'0'
	inc		bx
sw_continua2:


;	*string = '\0';
	mov		byte ptr[bx],0
		
;}
	ret
		
sprintf_w	endp

; fopen: String (dx) -> File* (bx) Boolean (CF)		(Passa o File* para o ax tambem, mas por algum motivo ele move pro bx)
; Obj.: Dado o caminho para um arquivo, devolve o ponteiro desse arquivo e define CF como 0 se o processo deu certo
; Ex.:
; lea dx, fileName		(em que fileName eh "temaDeCasa/feet/feet1.png",0) (Talvez a orientacao das barras varie com o sistema operacional, na duvida coloca tudo dentro de WORK pra poder usar so o nome do arquivo)
; call fopen
; -> bx recebe a imagem e CF (carry flag) nao ativa
; ou -> bx recebe lixo e CF ativa
fopen	proc	near
	mov		al,0
	mov		ah,3dh
	int		21h
	mov		bx,ax
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
	mov		cx,0
	mov		ah,3ch
	int		21h
	mov		bx,ax
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
	mov		ah,3eh
	int		21h
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
	mov		ah,3fh
	mov		cx,1
	lea		dx,FileBuffer
	int		21h
	mov		dl,FileBuffer
	ret
getChar	endp

; setChar: File* (bx) Char (dl) -> Inteiro (ax) Boolean (CF)
; Obj.: Dado um arquivo e um caractere, escreve esse caractere no arquivo e devolve a posicao do cursor e define CF como 0 se a leitura deu certo
; Ex.:
; mov bx, filePtr	(em que filePtr eh um ponteiro retornado por fopen/fcreate)
; call setChar
; -> posicao do cursor em AX e CF == 0 se deu certo
setChar	proc	near
	mov		ah,40h
	mov		cx,1
	mov		FileBuffer,dl
	lea		dx,FileBuffer
	int		21h
	ret
setChar	endp	

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