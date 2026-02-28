-- ============================================================================
-- SCRIPT DE CRÉATION DE LA BASE DE DONNÉES SAFETRACK GEOFENCING
-- PostgreSQL
-- Système de tracking GPS avec geofencing et contrôle de véhicules
-- ============================================================================

-- Activer l'extension PostGIS pour les calculs géographiques (optionnel mais recommandé)
-- CREATE EXTENSION IF NOT EXISTS postgis;

-- ============================================================================
-- TYPES ENUM
-- ============================================================================

-- Statut du véhicule
CREATE TYPE statut_vehicule_type AS ENUM ('ACTIF', 'INACTIF', 'MAINTENANCE', 'SUSPENDU');

-- Statut de position
CREATE TYPE statut_position_type AS ENUM ('OK', 'HORS_ZONE', 'ALERT', 'EN_MOUVEMENT', 'ARRET');

-- Type d'alerte
CREATE TYPE type_alerte_enum AS ENUM ('HORS_ZONE', 'VITESSE_EXCESSIVE', 'ARRET_PROLONGE', 'MOTEUR_COUPE', 'BATTERIE_FAIBLE');

-- Rôle utilisateur
CREATE TYPE role_utilisateur_type AS ENUM ('ADMIN', 'GESTIONNAIRE', 'SUPERVISEUR');

-- Type de commande downlink
CREATE TYPE type_commande_enum AS ENUM ('COUPER_MOTEUR', 'DEMARRER_MOTEUR', 'DEFINIR_ZONE', 'CHANGER_INTERVALLE');

-- Statut de commande
CREATE TYPE statut_commande_enum AS ENUM ('EN_ATTENTE', 'ENVOYEE', 'CONFIRMEE', 'ECHOUEE');

-- ============================================================================
-- TABLE : utilisateur
-- Gestionnaires du système de tracking
-- ============================================================================
CREATE TABLE utilisateur (
    id_utilisateur SERIAL PRIMARY KEY,
    nom VARCHAR(100) NOT NULL,
    prenom VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    telephone VARCHAR(20),
    mot_de_passe VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'GESTIONNAIRE',
    statut VARCHAR(20) DEFAULT 'ACTIF',
    derniere_connexion TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_user_role CHECK (role IN ('ADMIN', 'GESTIONNAIRE', 'SUPERVISEUR')),
    CONSTRAINT chk_user_statut CHECK (statut IN ('ACTIF', 'INACTIF', 'SUSPENDU'))
);

CREATE INDEX idx_user_email ON utilisateur(email);
CREATE INDEX idx_user_role ON utilisateur(role);

-- ============================================================================
-- TABLE : vehicule
-- Véhicules équipés de dispositifs GPS LoRaWAN
-- ============================================================================
CREATE TABLE vehicule (
    id_vehicule SERIAL PRIMARY KEY,
    nom VARCHAR(100) NOT NULL,
    immatriculation VARCHAR(50) UNIQUE,
    marque VARCHAR(50),
    modele VARCHAR(50),
    annee INTEGER,
    deveui VARCHAR(50) NOT NULL UNIQUE,
    appeui VARCHAR(50),
    appkey VARCHAR(255),
    statut VARCHAR(20) DEFAULT 'ACTIF',
    moteur_coupe BOOLEAN DEFAULT FALSE,
    mode_auto BOOLEAN DEFAULT FALSE,
    derniere_position_lat DECIMAL(10,8),
    derniere_position_lon DECIMAL(11,8),
    derniere_communication TIMESTAMP,
    id_utilisateur_proprietaire INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_vehicule_user
        FOREIGN KEY (id_utilisateur_proprietaire)
        REFERENCES utilisateur(id_utilisateur)
        ON DELETE SET NULL
        ON UPDATE CASCADE,
    
    CONSTRAINT chk_vehicule_statut CHECK (statut IN ('ACTIF', 'INACTIF', 'MAINTENANCE', 'SUSPENDU')),
    CONSTRAINT chk_annee CHECK (annee IS NULL OR (annee >= 1900 AND annee <= 2100))
);

CREATE INDEX idx_vehicule_deveui ON vehicule(deveui);
CREATE INDEX idx_vehicule_immat ON vehicule(immatriculation);
CREATE INDEX idx_vehicule_statut ON vehicule(statut);
CREATE INDEX idx_vehicule_user ON vehicule(id_utilisateur_proprietaire);

-- ============================================================================
-- TABLE : zone_securisee
-- Zones de geofencing (cercles définis par centre + rayon)
-- ============================================================================
CREATE TABLE zone_securisee (
    id_zone SERIAL PRIMARY KEY,
    nom VARCHAR(100) NOT NULL,
    description TEXT,
    latitude_centre DECIMAL(10,8) NOT NULL,
    longitude_centre DECIMAL(11,8) NOT NULL,
    rayon_metres INTEGER NOT NULL, -- Rayon en mètres
    couleur VARCHAR(20) DEFAULT '#00FF00', -- Pour affichage sur carte
    active BOOLEAN DEFAULT TRUE,
    type VARCHAR(20) DEFAULT 'CIRCLE', -- CIRCLE ou POLYGON
    coordinates JSON, -- Liste de points pour les polygones
    id_vehicule INTEGER, -- NULL = zone partagée, sinon zone spécifique à un véhicule
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_zone_vehicule
        FOREIGN KEY (id_vehicule)
        REFERENCES vehicule(id_vehicule)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    
    CONSTRAINT chk_latitude CHECK (latitude_centre >= -90 AND latitude_centre <= 90),
    CONSTRAINT chk_longitude CHECK (longitude_centre >= -180 AND longitude_centre <= 180),
    CONSTRAINT chk_rayon CHECK (rayon_metres > 0 AND rayon_metres <= 100000)
);

CREATE INDEX idx_zone_vehicule ON zone_securisee(id_vehicule);
CREATE INDEX idx_zone_active ON zone_securisee(active);

-- ============================================================================
-- TABLE : position_gps
-- Toutes les positions GPS reçues des véhicules
-- ============================================================================
CREATE TABLE position_gps (
    id_position SERIAL PRIMARY KEY,
    id_vehicule INTEGER NOT NULL,
    latitude DECIMAL(10,8) NOT NULL,
    longitude DECIMAL(11,8) NOT NULL,
    altitude DECIMAL(8,2), -- en mètres
    vitesse DECIMAL(6,2) NOT NULL, -- km/h
    cap DECIMAL(5,2), -- direction (0-360°)
    timestamp_gps TIMESTAMP NOT NULL, -- Horodatage du GPS
    fix_status SMALLINT, -- 0=pas de fix, 1=fix GPS
    satellites INTEGER, -- Nombre de satellites
    hdop DECIMAL(4,2), -- Précision horizontale
    statut VARCHAR(20) NOT NULL, -- OK, HORS_ZONE, ALERT, EN_MOUVEMENT, ARRET
    dans_zone BOOLEAN,
    distance_zone_metres DECIMAL(10,2), -- Distance par rapport au centre de la zone
    id_zone INTEGER, -- Zone de référence utilisée pour le calcul
    batterie_pourcentage INTEGER,
    payload_brut TEXT, -- Payload LoRaWAN brut pour debug
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_position_vehicule
        FOREIGN KEY (id_vehicule)
        REFERENCES vehicule(id_vehicule)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    
    CONSTRAINT fk_position_zone
        FOREIGN KEY (id_zone)
        REFERENCES zone_securisee(id_zone)
        ON DELETE SET NULL
        ON UPDATE CASCADE,
    
    CONSTRAINT chk_position_latitude CHECK (latitude >= -90 AND latitude <= 90),
    CONSTRAINT chk_position_longitude CHECK (longitude >= -180 AND longitude <= 180),
    CONSTRAINT chk_position_vitesse CHECK (vitesse >= 0 AND vitesse <= 500),
    CONSTRAINT chk_position_statut CHECK (statut IN ('OK', 'HORS_ZONE', 'ALERT', 'EN_MOUVEMENT', 'ARRET')),
    CONSTRAINT chk_position_batterie CHECK (batterie_pourcentage IS NULL OR (batterie_pourcentage >= 0 AND batterie_pourcentage <= 100))
);

CREATE INDEX idx_position_vehicule ON position_gps(id_vehicule);
CREATE INDEX idx_position_timestamp ON position_gps(timestamp_gps DESC);
CREATE INDEX idx_position_statut ON position_gps(statut);
CREATE INDEX idx_position_dans_zone ON position_gps(dans_zone);
CREATE INDEX idx_position_created ON position_gps(created_at DESC);

-- ============================================================================
-- TABLE : trajet
-- Trajets (séquence de positions avec début et fin)
-- ============================================================================
CREATE TABLE trajet (
    id_trajet SERIAL PRIMARY KEY,
    id_vehicule INTEGER NOT NULL,
    debut_timestamp TIMESTAMP NOT NULL,
    fin_timestamp TIMESTAMP,
    debut_lat DECIMAL(10,8),
    debut_lon DECIMAL(11,8),
    fin_lat DECIMAL(10,8),
    fin_lon DECIMAL(11,8),
    distance_totale_km DECIMAL(10,2),
    duree_minutes INTEGER,
    vitesse_moyenne DECIMAL(6,2),
    vitesse_max DECIMAL(6,2),
    nb_alertes INTEGER DEFAULT 0,
    en_cours BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_trajet_vehicule
        FOREIGN KEY (id_vehicule)
        REFERENCES vehicule(id_vehicule)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

CREATE INDEX idx_trajet_vehicule ON trajet(id_vehicule);
CREATE INDEX idx_trajet_debut ON trajet(debut_timestamp DESC);
CREATE INDEX idx_trajet_en_cours ON trajet(en_cours);

-- ============================================================================
-- TABLE : arret
-- Arrêts du véhicule (vitesse = 0 pendant un certain temps)
-- ============================================================================
CREATE TABLE arret (
    id_arret SERIAL PRIMARY KEY,
    id_vehicule INTEGER NOT NULL,
    id_trajet INTEGER,
    latitude DECIMAL(10,8) NOT NULL,
    longitude DECIMAL(11,8) NOT NULL,
    debut_timestamp TIMESTAMP NOT NULL,
    fin_timestamp TIMESTAMP,
    duree_minutes INTEGER,
    dans_zone BOOLEAN,
    en_cours BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_arret_vehicule
        FOREIGN KEY (id_vehicule)
        REFERENCES vehicule(id_vehicule)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    
    CONSTRAINT fk_arret_trajet
        FOREIGN KEY (id_trajet)
        REFERENCES trajet(id_trajet)
        ON DELETE SET NULL
        ON UPDATE CASCADE
);

CREATE INDEX idx_arret_vehicule ON arret(id_vehicule);
CREATE INDEX idx_arret_trajet ON arret(id_trajet);
CREATE INDEX idx_arret_en_cours ON arret(en_cours);

-- ============================================================================
-- TABLE : alerte
-- Alertes générées (hors zone, vitesse excessive, etc.)
-- ============================================================================
CREATE TABLE alerte (
    id_alerte SERIAL PRIMARY KEY,
    id_vehicule INTEGER NOT NULL,
    id_position INTEGER,
    type_alerte VARCHAR(50) NOT NULL,
    severite VARCHAR(20) DEFAULT 'MOYENNE', -- FAIBLE, MOYENNE, CRITIQUE
    message TEXT NOT NULL,
    details_json TEXT, -- JSON avec détails supplémentaires
    action_prise VARCHAR(100), -- MOTEUR_COUPE, NOTIFICATION_ENVOYEE, AUCUNE
    acquittee BOOLEAN DEFAULT FALSE,
    acquittee_par INTEGER,
    acquittee_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_alerte_vehicule
        FOREIGN KEY (id_vehicule)
        REFERENCES vehicule(id_vehicule)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    
    CONSTRAINT fk_alerte_position
        FOREIGN KEY (id_position)
        REFERENCES position_gps(id_position)
        ON DELETE SET NULL
        ON UPDATE CASCADE,
    
    CONSTRAINT fk_alerte_acquittee
        FOREIGN KEY (acquittee_par)
        REFERENCES utilisateur(id_utilisateur)
        ON DELETE SET NULL
        ON UPDATE CASCADE,
    
    CONSTRAINT chk_alerte_type CHECK (type_alerte IN ('HORS_ZONE', 'VITESSE_EXCESSIVE', 'ARRET_PROLONGE', 'MOTEUR_COUPE', 'BATTERIE_FAIBLE')),
    CONSTRAINT chk_alerte_severite CHECK (severite IN ('FAIBLE', 'MOYENNE', 'CRITIQUE'))
);

CREATE INDEX idx_alerte_vehicule ON alerte(id_vehicule);
CREATE INDEX idx_alerte_type ON alerte(type_alerte);
CREATE INDEX idx_alerte_acquittee ON alerte(acquittee);
CREATE INDEX idx_alerte_created ON alerte(created_at DESC);

-- ============================================================================
-- TABLE : commande_downlink
-- Commandes envoyées aux véhicules (couper moteur, définir zone, etc.)
-- ============================================================================
CREATE TABLE commande_downlink (
    id_commande SERIAL PRIMARY KEY,
    id_vehicule INTEGER NOT NULL,
    type_commande VARCHAR(50) NOT NULL,
    parametres_json TEXT, -- JSON avec paramètres de la commande
    statut VARCHAR(20) DEFAULT 'EN_ATTENTE',
    payload_envoye TEXT,
    fport INTEGER,
    date_envoi TIMESTAMP,
    date_confirmation TIMESTAMP,
    erreur TEXT,
    id_utilisateur_emetteur INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_commande_vehicule
        FOREIGN KEY (id_vehicule)
        REFERENCES vehicule(id_vehicule)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    
    CONSTRAINT fk_commande_user
        FOREIGN KEY (id_utilisateur_emetteur)
        REFERENCES utilisateur(id_utilisateur)
        ON DELETE SET NULL
        ON UPDATE CASCADE,
    
    CONSTRAINT chk_commande_type CHECK (type_commande IN ('COUPER_MOTEUR', 'DEMARRER_MOTEUR', 'DEFINIR_ZONE', 'CHANGER_INTERVALLE')),
    CONSTRAINT chk_commande_statut CHECK (statut IN ('EN_ATTENTE', 'ENVOYEE', 'CONFIRMEE', 'ECHOUEE'))
);

CREATE INDEX idx_commande_vehicule ON commande_downlink(id_vehicule);
CREATE INDEX idx_commande_statut ON commande_downlink(statut);
CREATE INDEX idx_commande_created ON commande_downlink(created_at DESC);

-- ============================================================================
-- TABLE : uplink_messages
-- Messages LoRaWAN bruts reçus de ChirpStack
-- ============================================================================
CREATE TABLE uplink_messages (
    id SERIAL PRIMARY KEY,
    application_id VARCHAR(100),
    application_name VARCHAR(100),
    device_name VARCHAR(100),
    device_profile_name VARCHAR(100),
    device_profile_id UUID,
    dev_eui VARCHAR(50),
    frequency BIGINT,
    dr INTEGER,
    adr BOOLEAN,
    f_cnt INTEGER,
    f_port INTEGER,
    data_base64 TEXT,
    text_payload TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processed BOOLEAN DEFAULT FALSE,
    error_message TEXT
);

-- Index
CREATE INDEX idx_uplink_deveui ON uplink_messages(dev_eui);
CREATE INDEX idx_uplink_processed ON uplink_messages(processed);
CREATE INDEX idx_uplink_created ON uplink_messages(created_at);

-- ============================================================================
-- TABLE : historique_statut
-- Historique des changements de statut des véhicules et positions
-- ============================================================================
CREATE TABLE historique_statut (
    id_historique SERIAL PRIMARY KEY,
    id_vehicule INTEGER NOT NULL,
    statut_precedent VARCHAR(20),
    statut_nouveau VARCHAR(20) NOT NULL,
    raison TEXT,
    details_json TEXT,
    id_utilisateur INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_histo_vehicule
        FOREIGN KEY (id_vehicule)
        REFERENCES vehicule(id_vehicule)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    
    CONSTRAINT fk_histo_user
        FOREIGN KEY (id_utilisateur)
        REFERENCES utilisateur(id_utilisateur)
        ON DELETE SET NULL
        ON UPDATE CASCADE
);

CREATE INDEX idx_histo_vehicule ON historique_statut(id_vehicule);
CREATE INDEX idx_histo_created ON historique_statut(created_at DESC);

-- ============================================================================
-- FONCTIONS UTILITAIRES
-- ============================================================================

-- Fonction pour calculer la distance Haversine entre deux points GPS
CREATE OR REPLACE FUNCTION calcul_distance_haversine(
    lat1 DECIMAL,
    lon1 DECIMAL,
    lat2 DECIMAL,
    lon2 DECIMAL
) RETURNS DECIMAL AS $$
DECLARE
    earth_radius CONSTANT DECIMAL := 6371000; -- Rayon de la Terre en mètres
    dlat DECIMAL;
    dlon DECIMAL;
    a DECIMAL;
    c DECIMAL;
    distance DECIMAL;
BEGIN
    -- Convertir les degrés en radians
    dlat := RADIANS(lat2 - lat1);
    dlon := RADIANS(lon2 - lon1);
    
    -- Formule Haversine
    a := SIN(dlat/2) * SIN(dlat/2) + 
         COS(RADIANS(lat1)) * COS(RADIANS(lat2)) * 
         SIN(dlon/2) * SIN(dlon/2);
    
    c := 2 * ATAN2(SQRT(a), SQRT(1-a));
    
    distance := earth_radius * c;
    
    RETURN ROUND(distance, 2);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION calcul_distance_haversine IS 
'Calcule la distance en mètres entre deux points GPS en utilisant la formule Haversine';

-- Fonction pour vérifier si un point est dans une zone
CREATE OR REPLACE FUNCTION est_dans_zone(
    p_lat DECIMAL,
    p_lon DECIMAL,
    p_id_zone INTEGER
) RETURNS BOOLEAN AS $$
DECLARE
    v_zone RECORD;
    v_distance DECIMAL;
BEGIN
    -- Récupérer les infos de la zone
    SELECT latitude_centre, longitude_centre, rayon_metres 
    INTO v_zone
    FROM zone_securisee
    WHERE id_zone = p_id_zone AND active = TRUE;
    
    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;
    
    -- Calculer la distance
    v_distance := calcul_distance_haversine(
        p_lat, p_lon,
        v_zone.latitude_centre, v_zone.longitude_centre
    );
    
    -- Vérifier si dans le rayon
    RETURN v_distance <= v_zone.rayon_metres;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION est_dans_zone IS 
'Vérifie si un point GPS est à l''intérieur d''une zone sécurisée';

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Trigger pour mettre à jour updated_at automatiquement
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_utilisateur_updated_at
    BEFORE UPDATE ON utilisateur
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_vehicule_updated_at
    BEFORE UPDATE ON vehicule
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_zone_updated_at
    BEFORE UPDATE ON zone_securisee
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger pour mettre à jour la dernière position du véhicule
CREATE OR REPLACE FUNCTION update_vehicule_derniere_position()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE vehicule
    SET 
        derniere_position_lat = NEW.latitude,
        derniere_position_lon = NEW.longitude,
        derniere_communication = NEW.created_at
    WHERE id_vehicule = NEW.id_vehicule;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_vehicule_position
    AFTER INSERT ON position_gps
    FOR EACH ROW EXECUTE FUNCTION update_vehicule_derniere_position();

-- Trigger pour créer une alerte lors d'une position HORS_ZONE
CREATE OR REPLACE FUNCTION create_alerte_hors_zone()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.statut = 'HORS_ZONE' OR NEW.statut = 'ALERT' THEN
        INSERT INTO alerte (
            id_vehicule,
            id_position,
            type_alerte,
            severite,
            message,
            details_json
        ) VALUES (
            NEW.id_vehicule,
            NEW.id_position,
            'HORS_ZONE',
            'CRITIQUE',
            format('Véhicule hors de la zone sécurisée. Distance: %s mètres', NEW.distance_zone_metres),
            json_build_object(
                'latitude', NEW.latitude,
                'longitude', NEW.longitude,
                'distance_metres', NEW.distance_zone_metres,
                'vitesse', NEW.vitesse
            )::TEXT
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_create_alerte_hors_zone
    AFTER INSERT ON position_gps
    FOR EACH ROW EXECUTE FUNCTION create_alerte_hors_zone();

-- Trigger pour gérer les trajets automatiquement
CREATE OR REPLACE FUNCTION gerer_trajet_automatique()
RETURNS TRIGGER AS $$
DECLARE
    v_trajet_en_cours RECORD;
    v_distance DECIMAL;
BEGIN
    -- Chercher un trajet en cours pour ce véhicule
    SELECT * INTO v_trajet_en_cours
    FROM trajet
    WHERE id_vehicule = NEW.id_vehicule 
      AND en_cours = TRUE
    ORDER BY debut_timestamp DESC
    LIMIT 1;
    
    -- Si le véhicule est EN_MOUVEMENT
    IF NEW.statut = 'EN_MOUVEMENT' THEN
        -- Si pas de trajet en cours, en créer un
        IF NOT FOUND THEN
            INSERT INTO trajet (
                id_vehicule,
                debut_timestamp,
                debut_lat,
                debut_lon,
                en_cours
            ) VALUES (
                NEW.id_vehicule,
                NEW.timestamp_gps,
                NEW.latitude,
                NEW.longitude,
                TRUE
            );
        ELSE
            -- Mettre à jour le trajet en cours
            IF v_trajet_en_cours.fin_lat IS NOT NULL THEN
                v_distance := calcul_distance_haversine(
                    v_trajet_en_cours.fin_lat,
                    v_trajet_en_cours.fin_lon,
                    NEW.latitude,
                    NEW.longitude
                ) / 1000; -- Convertir en km
            ELSE
                v_distance := 0;
            END IF;
            
            UPDATE trajet
            SET 
                fin_timestamp = NEW.timestamp_gps,
                fin_lat = NEW.latitude,
                fin_lon = NEW.longitude,
                distance_totale_km = COALESCE(distance_totale_km, 0) + v_distance,
                duree_minutes = EXTRACT(EPOCH FROM (NEW.timestamp_gps - debut_timestamp)) / 60,
                vitesse_max = GREATEST(COALESCE(vitesse_max, 0), NEW.vitesse)
            WHERE id_trajet = v_trajet_en_cours.id_trajet;
        END IF;
    
    -- Si le véhicule est en ARRET
    ELSIF NEW.statut = 'ARRET' THEN
        -- Terminer le trajet en cours si il existe
        IF FOUND THEN
            UPDATE trajet
            SET 
                en_cours = FALSE,
                fin_timestamp = NEW.timestamp_gps,
                fin_lat = NEW.latitude,
                fin_lon = NEW.longitude,
                duree_minutes = EXTRACT(EPOCH FROM (NEW.timestamp_gps - debut_timestamp)) / 60,
                vitesse_moyenne = CASE 
                    WHEN duree_minutes > 0 THEN distance_totale_km / (duree_minutes / 60)
                    ELSE 0
                END
            WHERE id_trajet = v_trajet_en_cours.id_trajet;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_gerer_trajet
    AFTER INSERT ON position_gps
    FOR EACH ROW EXECUTE FUNCTION gerer_trajet_automatique();

-- Trigger pour gérer les arrêts automatiquement
CREATE OR REPLACE FUNCTION gerer_arret_automatique()
RETURNS TRIGGER AS $$
DECLARE
    v_arret_en_cours RECORD;
BEGIN
    -- Chercher un arrêt en cours
    SELECT * INTO v_arret_en_cours
    FROM arret
    WHERE id_vehicule = NEW.id_vehicule 
      AND en_cours = TRUE
    ORDER BY debut_timestamp DESC
    LIMIT 1;
    
    -- Si le véhicule s'arrête
    IF NEW.statut = 'ARRET' AND NEW.vitesse = 0 THEN
        -- Si pas d'arrêt en cours, en créer un
        IF NOT FOUND THEN
            INSERT INTO arret (
                id_vehicule,
                latitude,
                longitude,
                debut_timestamp,
                dans_zone,
                en_cours
            ) VALUES (
                NEW.id_vehicule,
                NEW.latitude,
                NEW.longitude,
                NEW.timestamp_gps,
                NEW.dans_zone,
                TRUE
            );
        END IF;
    
    -- Si le véhicule repart
    ELSIF NEW.statut = 'EN_MOUVEMENT' AND NEW.vitesse > 0 THEN
        -- Terminer l'arrêt en cours
        IF FOUND THEN
            UPDATE arret
            SET 
                fin_timestamp = NEW.timestamp_gps,
                duree_minutes = EXTRACT(EPOCH FROM (NEW.timestamp_gps - debut_timestamp)) / 60,
                en_cours = FALSE
            WHERE id_arret = v_arret_en_cours.id_arret;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_gerer_arret
    AFTER INSERT ON position_gps
    FOR EACH ROW EXECUTE FUNCTION gerer_arret_automatique();

-- ============================================================================
-- TRIGGER PRINCIPAL : Parser les messages LoRaWAN SIM808
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_parser_sim808_gps()
RETURNS TRIGGER AS $$
DECLARE
    v_vehicule_id INTEGER;
    v_zone_id INTEGER;
    v_parts TEXT[];
    v_run_status SMALLINT;
    v_fix_status SMALLINT;
    v_datetime TEXT;
    v_latitude DECIMAL(10,8);
    v_longitude DECIMAL(11,8);
    v_altitude DECIMAL(8,2);
    v_vitesse DECIMAL(6,2);
    v_cap DECIMAL(5,2);
    v_timestamp TIMESTAMP;
    v_dans_zone BOOLEAN;
    v_distance_zone DECIMAL(10,2);
    v_statut VARCHAR(20);
BEGIN
    -- Vérifier que le payload n'est pas vide
    IF NEW.text_payload IS NULL OR NEW.text_payload = '' THEN
        NEW.processed := TRUE;
        NEW.error_message := 'Payload vide';
        RETURN NEW;
    END IF;

    -- Trouver le véhicule par DevEUI
    SELECT id_vehicule INTO v_vehicule_id
    FROM vehicule
    WHERE deveui = NEW.dev_eui AND statut = 'ACTIF';

    IF v_vehicule_id IS NULL THEN
        NEW.processed := TRUE;
        NEW.error_message := 'Véhicule non trouvé ou inactif pour DevEUI: ' || NEW.dev_eui;
        RETURN NEW;
    END IF;

    -- Parser le format CGNSINF
    -- Format: run_status,fix_status,datetime,lat,lon,alt,speed,course,fix_mode,...
    v_parts := string_to_array(NEW.text_payload, ',');

    IF array_length(v_parts, 1) < 9 THEN
        NEW.processed := TRUE;
        NEW.error_message := 'Format CGNSINF invalide';
        RETURN NEW;
    END IF;

    BEGIN
        v_run_status := CAST(TRIM(v_parts[1]) AS SMALLINT);
        v_fix_status := CAST(TRIM(v_parts[2]) AS SMALLINT);
        v_datetime := TRIM(v_parts[3]);
        
        -- Si pas de fix GPS, ignorer
        IF v_fix_status = 0 OR v_parts[4] = '' THEN
            NEW.processed := TRUE;
            NEW.error_message := 'Pas de fix GPS disponible';
            RETURN NEW;
        END IF;
        
        v_latitude := CAST(TRIM(v_parts[4]) AS DECIMAL(10,8));
        v_longitude := CAST(TRIM(v_parts[5]) AS DECIMAL(11,8));
        v_altitude := CASE 
            WHEN TRIM(v_parts[6]) = '' THEN NULL
            ELSE CAST(TRIM(v_parts[6]) AS DECIMAL(8,2))
        END;
        v_vitesse := CAST(TRIM(v_parts[7]) AS DECIMAL(6,2)); -- km/h
        v_cap := CASE 
            WHEN TRIM(v_parts[8]) = '' THEN NULL
            ELSE CAST(TRIM(v_parts[8]) AS DECIMAL(5,2))
        END;
        
        -- Parser le timestamp GPS (format: 20260206142530.000 = YYYYMMDDHHMMSS.sss)
        v_timestamp := TO_TIMESTAMP(
            SUBSTRING(v_datetime, 1, 14),
            'YYYYMMDDHH24MISS'
        );
        
    EXCEPTION WHEN OTHERS THEN
        NEW.processed := TRUE;
        NEW.error_message := 'Erreur parsing: ' || SQLERRM;
        RETURN NEW;
    END;

    -- Trouver la zone sécurisée du véhicule
    SELECT id_zone INTO v_zone_id
    FROM zone_securisee
    WHERE (id_vehicule = v_vehicule_id OR id_vehicule IS NULL)
      AND active = TRUE
    ORDER BY id_vehicule DESC NULLS LAST -- Priorité aux zones spécifiques
    LIMIT 1;

    -- Calculer si dans la zone
    IF v_zone_id IS NOT NULL THEN
        v_dans_zone := est_dans_zone(v_latitude, v_longitude, v_zone_id);
        
        SELECT calcul_distance_haversine(
            v_latitude, v_longitude,
            latitude_centre, longitude_centre
        ) INTO v_distance_zone
        FROM zone_securisee
        WHERE id_zone = v_zone_id;
    ELSE
        v_dans_zone := NULL;
        v_distance_zone := NULL;
    END IF;

    -- Déterminer le statut
    IF v_vitesse = 0 THEN
        v_statut := 'ARRET';
    ELSIF v_vitesse > 0 THEN
        v_statut := 'EN_MOUVEMENT';
    END IF;
    
    IF v_dans_zone = FALSE THEN
        v_statut := 'HORS_ZONE';
    ELSIF v_dans_zone = TRUE THEN
        IF v_statut = 'EN_MOUVEMENT' THEN
            v_statut := 'OK';
        END IF;
    END IF;

    -- Insérer la position GPS
    INSERT INTO position_gps (
        id_vehicule,
        latitude,
        longitude,
        altitude,
        vitesse,
        cap,
        timestamp_gps,
        fix_status,
        statut,
        dans_zone,
        distance_zone_metres,
        id_zone,
        payload_brut,
        created_at
    ) VALUES (
        v_vehicule_id,
        v_latitude,
        v_longitude,
        v_altitude,
        v_vitesse,
        v_cap,
        v_timestamp,
        v_fix_status,
        v_statut,
        v_dans_zone,
        v_distance_zone,
        v_zone_id,
        NEW.text_payload,
        COALESCE(NEW.created_at, NOW())
    );

    -- Marquer comme traité
    NEW.processed := TRUE;
    RAISE NOTICE 'Position GPS créée pour véhicule ID % - Statut: %', v_vehicule_id, v_statut;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_parser_sim808_gps
    BEFORE INSERT ON uplink_messages
    FOR EACH ROW
    EXECUTE FUNCTION fn_parser_sim808_gps();

COMMENT ON FUNCTION fn_parser_sim808_gps IS 
'Parse automatiquement les messages CGNSINF du SIM808 et crée les positions GPS avec calcul de geofencing';

-- ============================================================================
-- VUES UTILES
-- ============================================================================

-- Vue des positions récentes avec infos véhicule
CREATE VIEW v_positions_recentes AS
SELECT 
    p.id_position,
    p.timestamp_gps,
    p.latitude,
    p.longitude,
    p.vitesse,
    p.statut,
    p.dans_zone,
    p.distance_zone_metres,
    v.id_vehicule,
    v.nom AS vehicule_nom,
    v.immatriculation,
    v.deveui,
    z.nom AS zone_nom,
    z.rayon_metres AS zone_rayon,
    p.created_at
FROM position_gps p
JOIN vehicule v ON p.id_vehicule = v.id_vehicule
LEFT JOIN zone_securisee z ON p.id_zone = z.id_zone
ORDER BY p.created_at DESC;

-- Vue des alertes actives
CREATE VIEW v_alertes_actives AS
SELECT 
    a.id_alerte,
    a.type_alerte,
    a.severite,
    a.message,
    a.created_at,
    v.nom AS vehicule_nom,
    v.immatriculation,
    p.latitude,
    p.longitude,
    a.acquittee
FROM alerte a
JOIN vehicule v ON a.id_vehicule = v.id_vehicule
LEFT JOIN position_gps p ON a.id_position = p.id_position
WHERE a.acquittee = FALSE
ORDER BY a.created_at DESC;

-- Vue résumé des véhicules
CREATE VIEW v_vehicules_resume AS
SELECT 
    v.id_vehicule,
    v.nom,
    v.immatriculation,
    v.statut,
    v.derniere_position_lat,
    v.derniere_position_lon,
    v.derniere_communication,
    v.moteur_coupe,
    COUNT(DISTINCT a.id_alerte) FILTER (WHERE a.acquittee = FALSE) AS nb_alertes_actives,
    COUNT(DISTINCT t.id_trajet) FILTER (WHERE t.en_cours = TRUE) AS nb_trajets_en_cours
FROM vehicule v
LEFT JOIN alerte a ON v.id_vehicule = a.id_vehicule
LEFT JOIN trajet t ON v.id_vehicule = t.id_vehicule
GROUP BY v.id_vehicule;

-- ============================================================================
-- DONNÉES DE TEST (optionnel - à commenter en production)
-- ============================================================================

-- Admin par défaut
INSERT INTO utilisateur (nom, prenom, email, mot_de_passe, role) VALUES
('Admin', 'Système', 'admin@safetrack.cm', '$2a$10$dummyhash', 'ADMIN');

-- Véhicule de test
INSERT INTO vehicule (nom, immatriculation, marque, modele, deveui, statut) VALUES
('Camion 1', 'LT-1234-AB', 'Toyota', 'Hilux', '71F118B4E8F86E22', 'ACTIF');

-- Zone de test (Douala centre - environ 1km de rayon)
INSERT INTO zone_securisee (nom, description, latitude_centre, longitude_centre, rayon_metres) VALUES
('Zone Douala Centre', 'Zone de sécurité principale', 4.0511, 9.7679, 1000);

-- ============================================================================
-- FIN DU SCRIPT
-- ============================================================================
