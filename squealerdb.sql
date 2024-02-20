
/*------------------------------ creazione db ---------------------------------------*/
drop database if exists squealerdb;
create database squealerdb ;
use squealerdb;

/* ----------------------------SCHELETRO DB--------------------------------------- */

CREATE TABLE Utente(
mail VARCHAR(30) primary key,
pass VARCHAR(30),
nome VARCHAR(30),
cognome VARCHAR(30),
maxCharD int default 3000,
maxCharW int default 7000,
maxCharM int default 28000,
quotaP int default 1,
quotaN int default 1,
extra int default 0,
foto varchar (1000),
stato enum("bloccato", "sbloccato") default "sbloccato"
)ENGINE="InnoDB";


CREATE TABLE Canale(
nome varchar(100) primary KEY,
descrizione varchar(100) default "-",
proprietarioEMail varchar(30),
tipo ENUM("lettereMax","lettereMin"),
stato ENUM("bloccato","sbloccato") default "sbloccato",
FOREIGN KEY(proprietarioEmail) REFERENCES Utente(mail) on delete cascade
)ENGINE="InnoDB";

CREATE TABLE RichiestaAcquistoCanale(
id INT auto_increment primary KEY,
acquirente varchar(30),
venditore varchar(30),
canale varchar(100),
esito ENUM("in attesa", "accettata", "rifiutata") DEFAULT "in attesa",
FOREIGN KEY(acquirente) REFERENCES Utente(mail) on delete cascade on update cascade,
FOREIGN KEY(venditore) REFERENCES Utente(mail) on delete cascade on update cascade,
FOREIGN KEY(canale) REFERENCES Canale(nome) on delete cascade
)ENGINE="InnoDB";


CREATE TABLE Moderatore(
emailModeratore varchar(30),
foreign key (emailModeratore) references Utente(mail) on delete cascade
)ENGINE="InnoDB";


CREATE TABLE Localita(
	id int auto_increment primary key,
    latitude decimal(9,6),
    longitude decimal(9,6)
)ENGINE="InnoDB";

CREATE TABLE Messaggio(
	id int auto_increment primary KEY,
	testo VARCHAR(3000),
	link varchar(100),
	latitude decimal(9,6),
	longitude decimal(9,6),
	immagine varchar(100),
	destinatario varchar(100),
    mittente varchar(100),
	impressionX int,
	categoria ENUM("privato","pubblico"),
    popolarita ENUM("popolare","impopolare","controverso"),
    menzionato varchar(30),
  data varchar(120)
)ENGINE="InnoDB";


CREATE TABLE Commento (
    id INT AUTO_INCREMENT PRIMARY KEY,
    idMessaggio INT,
    emailMittente VARCHAR(30), -- Nuova colonna per l'email del mittente
    emailDestinatario VARCHAR(30), -- Nuova colonna per l'email del destinatario
    testo VARCHAR(255), 
    FOREIGN KEY (emailMittente) REFERENCES Utente (mail) ON DELETE CASCADE,
    FOREIGN KEY (emailDestinatario) REFERENCES Utente (mail) ON DELETE CASCADE,
    FOREIGN KEY (idMessaggio) REFERENCES Messaggio (id) ON DELETE CASCADE
) ENGINE = InnoDB;






/*I messaggi in base alle reazioni positive e negative possono diventare popolari o impopolari*/
CREATE TABLE Apprezzamento(
	idMessaggio int,
	mailUtente varchar(30),
	data datetime,
	giudizio ENUM("positivo", "negativo"),
	primary key(idMessaggio, mailUtente),
	foreign key (mailUtente) references Utente(mail) on delete cascade,
	foreign key (idMessaggio) references Messaggio(id) on delete cascade
)ENGINE="InnoDB";


/*
§canale (lettere minuscole) è un canale di squeal di proprietà di uno o
più utenti, che decidono chi può leggerli e chi può scriverne di nuovi.
§ §CANALE (lettere maiuscole) sono canali riservati a SQUEALER e gestiti
dalla redazione. 
*/




CREATE TABLE AdminCanale(
nomeCanale varchar(100) ,
emailUtente varchar(100),
primary key(nomeCanale,emailUtente),
foreign key (nomeCanale) references Canale(nome) on delete cascade,
foreign key (emailUtente) references Utente(mail) on delete cascade
)ENGINE="InnoDB";


CREATE TABLE UtenteVip(
emailVip varchar(30),
foreign key (emailVip) references Utente(mail) on delete cascade
)ENGINE="InnoDB";


CREATE TABLE IscrittiCanale(
nomeCanale varchar(30),
iscritto varchar(30),
primary key(nomeCanale, iscritto),
foreign key (nomeCanale) references Canale(nome) on delete cascade,
foreign key (iscritto) references Utente(mail) on delete cascade
)ENGINE="InnoDB";

/*----------------------------CREAZIONE DEI TRIGGER----------------------------------------*/



/*----------------------------------------TRIGGER TEPORIZZATO EVENTO---------------------------------*/

DELIMITER |
|DELIMITER;



CREATE PROCEDURE AggiornaQuotaUtente(IN idMessaggio int, IN Azione VARCHAR(10))
BEGIN
    DECLARE charAggiuntaDiminuzione INT default 5;
    DECLARE quota INT;
    DECLARE mittente varchar(100);
    DECLARE nReazioni INT;
    DECLARE caratteri INT;

    -- Calcola il numero di messaggi popolari e impopolari dell'utente
    set mittente = SELECT mittente FROM messaggio WHERE messaggio.id = idMessaggio;
	
    IF Azione = 'Aumento' THEN
        set nReazioni = SELECT count(*) FROM apprezzamenti WHERE apprezzamenti.idMessaggio = idMessaggio where apprezzamenti.giudizio = 'positivo';
        if nReazioni/10 > quota then
			update utente set quotaP = nReazioni/10;
            set quota =  nReazioni/10;
			set caratteri = charAggiuntaDiminuzione*quota;
			call Aggiunta(mittente,caratteri);
		else
			set quota =  SELECT quotaP FROM utente WHERE utente.mail = mittente;
            set caratteri = charAggiuntaDiminuzione*quota;
			call Aggiunta(mittente,caratteri);
		end if;
    ELSE
        set nReazioni = SELECT count(*) FROM apprezzamenti WHERE apprezzamenti.idMessaggio = idMessaggio where apprezzamenti.giudizio = 'negativo';
        if nReazioni/10 > quota then
			update utente set quotaN = nReazioni/10;
            set quota =  nReazioni/10;
			set caratteri = charAggiuntaDiminuzione*quota;
			call Consumo(mittente,caratteri);
		else
			set quota =  SELECT quotaN FROM utente WHERE utente.mail = mittente;
            set caratteri = charAggiuntaDiminuzione*quota;
			call Consumo(mittente,caratteri);
		end if;
    END IF;
END;

//

CREATE TRIGGER AggiornaQuotaUtenteDopoReazione
AFTER INSERT ON Apprezzamento
FOR EACH ROW
BEGIN
    DECLARE Azione VARCHAR(10);

    -- Determina se l'azione è positiva o negativa
    IF NEW.giudizio = 'positivo' THEN
        SET Azione = 'Aumento';
    ELSE
        SET Azione = 'Diminuzione';
    END IF;

    -- Aggiorna la quota dell'utente
    CALL AggiornaQuotaUtente(NEW.idMessaggio, Azione);
END;





/*---------------------------STORED PROCEDURES-----------------------------------*/

/*INSERIMENTO, ELIMINAZIONE E MODIFICA DI UTENTI(BASE, PREMIUM, AMMINISTRATORE), SONDAGGI, DOMANDE, DOMINI, AZIENDI, PREMIO INVITO */

/*AGGIUNGERE UN VALORE DI OUTPUT DI CONTROLLO TRUE O FALSE PER VEDERE SE E' ANDATA A BUON FINE LA PROCEDEURA O NO */
/*Funzioni di accounting*/
/* Creazione account, cambio password, reset password, eliminazione*/


DELIMITER //
CREATE PROCEDURE ContaGiudiziPositiviPerMittente(IN p_mittente VARCHAR(100))
BEGIN
	
    SELECT COUNT(*) as conteggio
    FROM apprezzamento as a
    JOIN messaggio as m ON a.idMessaggio = m.id
    WHERE m.mittente = p_mittente AND a.giudizio = 'positivo';
    
END //

DELIMITER ;

DELIMITER //
CREATE PROCEDURE ContaGiudiziNegativiPerMittente(IN p_mittente VARCHAR(100))
BEGIN
    SELECT COUNT(*) as conteggio
    FROM Apprezzamento a
    JOIN Messaggio m ON a.idMessaggio = m.id
    WHERE m.mittente = p_mittente AND a.giudizio = 'negativo';
END //

DELIMITER ;


DELIMITER |
CREATE PROCEDURE InserisciUtente (IN Email VARCHAR(30), Password varchar(30), Nome VARCHAR(30), Cognome VARCHAR(30)) 
BEGIN
  DECLARE VerificaEmail INT DEFAULT 0;  
  set VerificaEmail = (select count(*) from Utente where (Email = Utente.mail));
    IF (VerificaEmail<1) THEN 
    INSERT INTO Utente(mail,pass,nome,cognome) VALUES (Email,Password,Nome,Cognome);
    END IF;
END
| DELIMITER ;

DELIMITER |
CREATE PROCEDURE CambioPassword(IN Email_utente VARCHAR(30),newPass VARCHAR(30)) 
BEGIN
	DECLARE VerificaEmail INT DEFAULT 0;  
	set VerificaEmail = (select count(*) from Utente where (Email_utente = Utente.mail));

    IF (VerificaEmail=1) THEN
    update Utente set pass = newPass WHERE  (Email_utente = Utente.mail);
         END IF;
END;
| DELIMITER ;

DELIMITER |
CREATE PROCEDURE deleteAccount(IN Email_utente VARCHAR(30)) 
BEGIN
	 -- Controlla se l'account esiste
    IF EXISTS(SELECT * FROM Utente WHERE Email_utente = Utente.mail) THEN
        -- Cancella l'account
        DELETE FROM Utente WHERE Email_utente = Utente.mail;
        SELECT 'Account cancellato con successo.';
    ELSE
        SELECT 'L\'account non esiste.';
    END IF;
END;

/* Tipo di account: normale, verificato, VIP o moderatore squealer*/ 

/* Acquisto caratteri aggiuntivi giornalieri, settimanali, mensili (solo
verificati e professional).*/
DELIMITER |
CREATE PROCEDURE AcquistoCharD(IN Email_utente VARCHAR(30),newChar int) 
BEGIN
	DECLARE VerificaEmail INT DEFAULT 0;  
	set VerificaEmail = (select count(*) from Utente where (Email_utente = Utente.mail));
	
    IF (VerificaEmail=1) THEN
    update Utente set maxCharD = (maxCharD+newChar) WHERE  (Email_utente = Utente.mail);
         END IF;
END;
| DELIMITER ;
DELIMITER |
CREATE PROCEDURE AcquistoCharW(IN Email_utente VARCHAR(30),newChar int) 
BEGIN
	DECLARE VerificaEmail INT DEFAULT 0;  
	set VerificaEmail = (select count(*) from Utente where (Email_utente = Utente.mail));
	
    IF (VerificaEmail=1) THEN
    update Utente set maxCharW = (maxCharW+newChar) WHERE  (Email_utente = Utente.mail);
         END IF;
END;

| DELIMITER ;
DELIMITER |
CREATE PROCEDURE AcquistoCharM(IN Email_utente VARCHAR(30),newChar int) 
BEGIN
	DECLARE VerificaEmail INT DEFAULT 0;  
	set VerificaEmail = (select count(*) from Utente where (Email_utente = Utente.mail));
	
    IF (VerificaEmail=1) THEN
    update Utente set maxCharM = (maxCharM+newChar) WHERE  (Email_utente = Utente.mail);
         END IF;
END;
| DELIMITER ;

/* Tipo di account: normale, verificato, VIP o moderatore squealer*/ 
DELIMITER |
CREATE PROCEDURE InserisciUtenteVip (IN Email VARCHAR(30), Password varchar(30)) 
BEGIN
  DECLARE VerificaEmail INT DEFAULT 0;  
  set VerificaEmail = (select count(*) from Utente where (Email = Utente.mail));
    IF (VerificaEmail<1) THEN 
    INSERT INTO Utente(mail,pass) VALUES (Email,Password);
  INSERT INTO UtenteVip(emailVip) VALUES (Email);
    
    END IF;
END
| DELIMITER ;


DELIMITER |
CREATE PROCEDURE InserisciUtenteModeratore (IN Email VARCHAR(30), Password varchar(30), Nome VARCHAR(30), Cognome VARCHAR(30)) 
BEGIN
  DECLARE VerificaEmail INT DEFAULT 0;  
  set VerificaEmail = (select count(*) from Utente where (Email = Utente.mail));
    IF (VerificaEmail<1) THEN 
    INSERT INTO Utente(mail,pass,nome,cognome) VALUES (Email,Password,Nome,Cognome);
  INSERT INTO Moderatore(emailModeratore) VALUES (Email);
    
    END IF;
END
| DELIMITER ;


DELIMITER |


DELIMITER |
CREATE PROCEDURE SelezionaMenzioni(IN men VARCHAR(30))
BEGIN    
    SELECT *
    FROM Menzione,Utente
    WHERE (men=Menzione.menzionato) and (Utente.mail=men)  
    UNION
	SELECT *
    FROM Menzione,Utente
    WHERE (men=Menzione.menzionato) and (Canale.nome=men);   
END;
|
DELIMITER 



DELIMITER //
CREATE PROCEDURE SelezionaMessaggiCanaliPubblici()
BEGIN    
    SELECT *
    FROM Messaggio
    WHERE condizione_tabella1;   
END;
//
DELIMITER ;


DELIMITER |
CREATE PROCEDURE creaCanaleLetteraMax(IN nomeCanale VARCHAR(100))
BEGIN
  INSERT INTO Canale (nome, tipo) VALUES (nomeCanale, 'lettereMax');
END;
|
DELIMITER ;


DELIMITER //
CREATE PROCEDURE SelezionaCanaliPropietà(IN Email VARCHAR(30))
BEGIN    
    SELECT *
    FROM Canale
    WHERE (Email=Canale.proprietarioEmail);   
END;
//
DELIMITER ;


DELIMITER //
CREATE PROCEDURE SelezionaMessaggiUtente(IN Email VARCHAR(30))
BEGIN
    DECLARE resultJson TEXT;
    DECLARE rowJson TEXT;
    DECLARE done INT DEFAULT 0;
    DECLARE messageId INT;
    DECLARE messageText TEXT;
    DECLARE cur CURSOR FOR
        SELECT Messaggio.id, Messaggio.testo
        FROM Messaggio, Utente, Localita
        WHERE (Messaggio.mittente = Utente.mail) AND (Localita.id = Messaggio.localita) AND (
            (Email = Messaggio.destinatario) OR (Messaggio.categoria = "pubblico") OR (
                Messaggio.destinatario IN (
                    SELECT IscrittiCanale.nomeCanele
                    FROM IscrittiCanale
                    WHERE (Email = IscrittiCanale.iscritto)
                )
            )
        );

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    SET SESSION group_concat_max_len = 1000000;

    OPEN cur;
SET resultJson = '[';

    read_loop: LOOP
        FETCH cur INTO messageId, messageText;
        IF done THEN
            LEAVE read_loop;
        END IF;

        SET rowJson = JSON_OBJECT('id', messageId, 'testo', messageText);
        IF resultJson != '[' THEN
            SET resultJson = CONCAT(resultJson, ',', rowJson);
        ELSE
            SET resultJson = CONCAT(resultJson, rowJson);
        END IF;
    END LOOP;

    CLOSE cur;

    SET resultJson = CONCAT(resultJson, ']');
    SELECT resultJson AS result;
END;
//
DELIMITER ;


DELIMITER //
CREATE PROCEDURE SelezionaCanaliNonIscritto(IN Email VARCHAR(30))
BEGIN    
    SELECT *
    FROM Canale
    WHERE (Canale.nome NOT IN(
		SELECT IscrittiCanale.nomeCanele
        FROM IscrittiCanale
        WHERE (IscrittiCanale.iscritto=Email)
    )); 
      
END;
//


DELIMITER //
CREATE PROCEDURE SelezionaCanaliIscritto(IN Email VARCHAR(30))
BEGIN    
    SELECT *
    FROM Canale
    WHERE (Canale.nome IN(
		SELECT IscrittiCanale.nomeCanele
        FROM IscrittiCanale
        WHERE (IscrittiCanale.iscritto=Email)
    )); 
      
END;
//


DELIMITER |
CREATE PROCEDURE Inscrizione (IN nomeCanale VARCHAR(100), emailUtente VARCHAR(100))
BEGIN	
    INSERT INTO IscrittiCanale(nomeCanale, iscritto) values(nomeCanale,emailUtente);
END
| DELIMITER ;


DELIMITER |
CREATE PROCEDURE AggiungiReazionePos (IN idMessaggio INT, IN mail VARCHAR(100))
BEGIN	

	DECLARE verificaControverso INT DEFAULT 0;  
    DECLARE mailUtenteMess varchar(30);

    IF((SELECT count(*) FROM messaggio WHERE (id = idMessaggio) AND (categoria = 'controverso')) > 0) THEN
    
		UPDATE messaggio SET categoria = 'pubblico' WHERE id = idMessaggio;
		
    END IF;

    INSERT INTO Apprezzamento(idMessaggio, mailUtente, giudizio) values(idMessaggio, mail, "positivo");
    
	set verificaControverso = (SELECT count(*) 
							FROM messaggio, giudizipositivi, giudizinegativi 
							WHERE (id = idMessaggio)
								AND (id = giudizipositivi.idMessaggio) 
								AND (id = giudizinegativi.idMessaggio) 
								AND (giudizipositivi.idMessaggio = giudizinegativi.idMessaggio) 
								AND ((numGiudiziPositivi - numGiudiziNegativi) = 0)); 
    
    IF(verificaControverso > 0) THEN
    
		UPDATE messaggio SET popolarita = 'controverso' WHERE id = idMessaggio;
    
    END IF;
    
	set mailUtenteMess = (SELECT mittente FROM messaggio WHERE messaggio.id = idMessaggio);
    
	update utente set maxCharM = (maxCharM+5) WHERE (mailUtenteMess = utente.mail);
	update utente set maxCharW = (maxCharW+5) WHERE (mailUtenteMess = utente.mail);
	update utente set maxCharD = (maxCharD+5) WHERE (mailUtenteMess = utente.mail);
    
END
| DELIMITER ;

DELIMITER |

CREATE PROCEDURE AggiungiReazioneNeg (IN idMessaggio INT, IN mail VARCHAR(100))
BEGIN	

	DECLARE verificaControverso INT DEFAULT 0;  
    DECLARE mailUtenteMess varchar(30);

    IF((SELECT count(*) FROM messaggio WHERE (id = idMessaggio) AND (categoria = 'controverso')) > 0) THEN
    
		UPDATE messaggio SET categoria = 'pubblico' WHERE id = idMessaggio;
		
    END IF;
    
    INSERT INTO Apprezzamento(idMessaggio, mailUtente, giudizio) values(idMessaggio, mail, "negativo");
        
	set verificaControverso = (SELECT count(*) 
								FROM messaggio, giudizipositivi, giudizinegativi 
								WHERE (id = idMessaggio)
									AND (id = giudizipositivi.idMessaggio) 
									AND (id = giudizinegativi.idMessaggio) 
									AND (giudizipositivi.idMessaggio = giudizinegativi.idMessaggio) 
									AND ((numGiudiziPositivi - numGiudiziNegativi) = 0)); 
    
	IF(verificaControverso > 0) THEN
    
		UPDATE messaggio SET popolarita = 'controverso' WHERE id = idMessaggio;
    
    END IF;
    
	set mailUtenteMess = (SELECT mittente FROM messaggio WHERE messaggio.id = idMessaggio);
    
	update utente set maxCharM = (maxCharM-5) WHERE (mailUtenteMess = utente.mail);
	update utente set maxCharW = (maxCharW-5) WHERE (mailUtenteMess = utente.mail);
	update utente set maxCharD = (maxCharD-5) WHERE (mailUtenteMess = utente.mail);
    
END
| DELIMITER ;


DELIMITER |
CREATE PROCEDURE AggiungiAdmin (IN nomeC VARCHAR(100),mail VARCHAR(100))
BEGIN	
    INSERT INTO AdminCanale(nomeCanale, emailUtente) values(nomeC,mail);
END
| DELIMITER ;


DELIMITER //
CREATE PROCEDURE CreareNuovoCommento (
    IN p_idMessaggio INT,
    IN p_emailMittente VARCHAR(30),
    IN p_emailDestinatario VARCHAR(30),
    IN p_testo VARCHAR(255)
)
BEGIN
    DECLARE v_mittenteEsistente INT;
    DECLARE v_destinatarioEsistente INT;

    -- Verifica se l'email del mittente esiste nella tabella Utente
    set v_mittenteEsistente = 
    (SELECT COUNT(*)
    FROM Utente
    WHERE mail = p_emailMittente);

    -- Verifica se l'email del destinatario esiste nella tabella Utente
     set v_destinatarioEsistente = 
    (SELECT COUNT(*)
    FROM Utente
    WHERE mail = p_emailDestinatario);

    -- Verifica se l'idMessaggio esiste nella tabella Messaggio
    IF v_mittenteEsistente = 1 AND v_destinatarioEsistente = 1 THEN
        INSERT INTO Commento (idMessaggio, emailMittente, emailDestinatario, testo)
        VALUES (p_idMessaggio, p_emailMittente, p_emailDestinatario, p_testo);
	
    END IF;
END //

DELIMITER ;


DELIMITER |
CREATE PROCEDURE AggiungiMenzione (IN idMes VARCHAR(100),men VARCHAR(100))
BEGIN	
    INSERT INTO Menzione(idMessaggio, menzionato) values(idMes,men);
END
| DELIMITER ;






DELIMITER |
CREATE PROCEDURE ConsumoCharD(IN Email_utente VARCHAR(30),newChar int) 
BEGIN
  DECLARE VerificaEmail INT DEFAULT 0;  
  set VerificaEmail = (select count(*) from Utente where (Email_utente = Utente.mail));

    IF (VerificaEmail=1) THEN
    update Utente set charD = (charD-newChar) WHERE  (Email_utente = Utente.mail);
         END IF;
END;
| DELIMITER ;

DELIMITER |
CREATE PROCEDURE ConsumoCharW(IN Email_utente VARCHAR(30),newChar int) 
BEGIN
  DECLARE VerificaEmail INT DEFAULT 0;  
  set VerificaEmail = (select count(*) from Utente where (Email_utente = Utente.mail));

    IF (VerificaEmail=1) THEN
    update Utente set charW = (charW-newChar) WHERE  (Email_utente = Utente.mail);
         END IF;
END;
| DELIMITER ;

DELIMITER |
CREATE PROCEDURE ConsumoCharM(IN Email_utente VARCHAR(30),newChar int) 
BEGIN
  DECLARE VerificaEmail INT DEFAULT 0;  
  set VerificaEmail = (select count(*) from Utente where (Email_utente = Utente.mail));

    IF (VerificaEmail=1) THEN
    update Utente set charM = (charM-newChar) WHERE  (Email_utente = Utente.mail);
         END IF;
END;
| DELIMITER ;


DELIMITER |

CREATE PROCEDURE Consumo(IN Email_utente VARCHAR(30), newChar INT)
BEGIN
  DECLARE VerificaEmail INT DEFAULT 0;  

  -- Use SELECT INTO to assign the count to VerificaEmail
  SELECT COUNT(*) INTO VerificaEmail FROM Utente WHERE (Email_utente = Utente.mail);

  IF (VerificaEmail = 1) THEN
    -- Combine the updates into a single UPDATE statement
    UPDATE Utente 
    SET maxCharM = (maxCharM - newChar),
        maxCharW = (maxCharW - newChar),
        maxCharD = (maxCharD - newChar)
    WHERE (Email_utente = Utente.mail);
  END IF;
END |DELIMITER ;

DELIMITER |

CREATE PROCEDURE Aggiunta(IN Email_utente VARCHAR(30), newChar INT)
BEGIN
  DECLARE VerificaEmail INT DEFAULT 0;  

  -- Use SELECT INTO to assign the count to VerificaEmail
  SELECT COUNT(*) INTO VerificaEmail FROM Utente WHERE (Email_utente = Utente.mail);

  IF (VerificaEmail = 1) THEN
    -- Combine the updates into a single UPDATE statement
    UPDATE Utente 
    SET maxCharM = (maxCharM + newChar),
        maxCharW = (maxCharW + newChar),
        maxCharD = (maxCharD + newChar)
    WHERE (Email_utente = Utente.mail);
  END IF;
END |DELIMITER ;




DELIMITER |
CREATE PROCEDURE InserisciMessaggio (IN Testo VARCHAR(3000), Link VARCHAR(100), lat decimal(9,6),lon decimal(9,6), Immagine VARCHAR(100), Destinatario VARCHAR(100), Mittente VARCHAR(100), ImpressionX INT, Categoria ENUM("Privato", "Pubblico", "Controverso"), DataMessaggio varchar(120), menz VARCHAR(100)) 
BEGIN
  
    INSERT INTO Messaggio(testo, link, latitude,longitude, immagine, destinatario, mittente, impressionX, categoria, data,menzionato) VALUES (Testo, Link, lat,lon, Immagine, Destinatario, Mittente, ImpressionX, Categoria,DataMessaggio,menz);
END
| DELIMITER ;

DELIMITER |
CREATE PROCEDURE InserisciRichiestaAcquisto (IN acquirente VARCHAR(30), canale VARCHAR(100)) 
BEGIN

	DECLARE proprietarioCanale VARCHAR(30);
	SET proprietarioCanale = (SELECT proprietarioEmail FROM Canale WHERE nome=canale);
  
	INSERT INTO RichiestaAcquistoCanale(acquirente, venditore, canale) VALUES (acquirente, proprietarioCanale, canale);
   
END
| DELIMITER ;


/*IMPORTANTE SE HO UN DESTINATARIO CHE SIA UN CANALE O UNO USER IL MESSAGGIO è PRIVATO*/

/* DEFINIZIONE DELLE VISTE */

CREATE VIEW GIUDIZIPOSITIVI (idMessaggio, numGiudiziPositivi) AS
SELECT id, count(*) as giudiziPositivi 
FROM Messaggio, Apprezzamento 
WHERE (id = idMessaggio) AND (giudizio = "positivo") 
GROUP BY idMessaggio;

CREATE VIEW GIUDIZINEGATIVI (idMessaggio, numGiudiziNegativi) AS
SELECT id, count(*) as giudiziNegativi
FROM Messaggio, Apprezzamento 
WHERE (id = idMessaggio) AND (giudizio = "negativo") 
GROUP BY idMessaggio;

/*#########################################################################################*/
call InserisciUtenteVip("vip@gmail.com", "vip");
call InserisciUtenteModeratore("mod@gmail.com","mod","mod","mod");


INSERT INTO Canale (nome, tipo) VALUES ("$TRENDING","lettereMax");
INSERT INTO Canale (nome, tipo) VALUES ("$NEWS","lettereMax");
INSERT INTO Canale (nome, tipo) VALUES ("$ALL","lettereMax");
INSERT INTO Canale (nome, tipo) VALUES ("$EMERGENCY","lettereMax");
INSERT INTO Canale (nome, tipo) VALUES ("$CONTROVERSIAL_TOP","lettereMax");



call InserisciMessaggio("annunciati i partecipanti al nuovo reality", "http://wikipedia.it", 45.678910, 9.123456, null , "$TRENDING" , "mod@gmail.com", 10 , "Pubblico", "2023-08-06", null);
call InserisciMessaggio("notizie di cronaca", "http://wikipedia.it", 45.678910, 9.123456, null, "$NEWS" , "mod@gmail.com", 10 , "Pubblico", "2023-08-06", null);
call InserisciMessaggio("tutte le notizie", "http://wikipedia.it", 45.678910, 9.123456, null, "$ALL" , "mod@gmail.com",  10 , "Pubblico", "2023-08-06", null);
call InserisciMessaggio("trovato ferito in via rizzoli", "http://wikipedia.it", 45.678910, 9.123456, null, "$EMERGENCY" , "mod@gmail.com", 10 , "Pubblico", "2023-08-06", null);
call InserisciMessaggio("inserito il limite dei 30 km/h", "http://wikipedia.it", 45.678910, 9.123456, null, "$CONTROVERSIAL_TOP" , "mod@gmail.com", 10 , "Pubblico", "2023-08-06", null);



