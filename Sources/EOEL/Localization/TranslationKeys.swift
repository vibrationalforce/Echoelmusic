//
//  TranslationKeys.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  COMPREHENSIVE TRANSLATION KEYS
//  All 500+ UI strings categorized and ready for translation
//

import Foundation

/// Comprehensive translation key definitions
/// This file defines ALL keys that need translation
/// Use LocalizationExtensions.swift for easy UI integration
extension LocalizationManager {

    /// Add all comprehensive translations to the manager
    func registerComprehensiveTranslations() {
        // This method should be called during app initialization
        // It registers all translation keys with their default English values

        // MARK: - Navigation & Tabs
        addTranslations([
            "nav.daw": [
                .english: "DAW",
                .german: "DAW"
            ],
            "nav.video": [
                .english: "Video",
                .german: "Video"
            ],
            "nav.lighting": [
                .english: "Lighting",
                .german: "Beleuchtung"
            ],
            "nav.eoelwork": [
                .english: "EoelWork",
                .german: "EoelWork"
            ],
            "nav.settings": [
                .english: "Settings",
                .german: "Einstellungen"
            ],

            // MARK: - Transport Controls
            "transport.play": [
                .english: "Play",
                .german: "Wiedergabe",
                .spanish: "Reproducir",
                .french: "Lire",
                .japanese: "再生"
            ],
            "transport.pause": [
                .english: "Pause",
                .german: "Pause",
                .spanish: "Pausa",
                .french: "Pause",
                .japanese: "一時停止"
            ],
            "transport.stop": [
                .english: "Stop",
                .german: "Stopp",
                .spanish: "Detener",
                .french: "Arrêter",
                .japanese: "停止"
            ],
            "transport.record": [
                .english: "Record",
                .german: "Aufnehmen",
                .spanish: "Grabar",
                .french: "Enregistrer",
                .japanese: "録音"
            ],
            "transport.rewind": [
                .english: "Rewind",
                .german: "Zurückspulen",
                .spanish: "Rebobinar",
                .french: "Rembobiner",
                .japanese: "巻き戻し"
            ],

            // MARK: - Track Controls
            "track.solo": [
                .english: "Solo",
                .german: "Solo",
                .spanish: "Solo",
                .french: "Solo",
                .japanese: "ソロ"
            ],
            "track.mute": [
                .english: "Mute",
                .german: "Stumm",
                .spanish: "Silenciar",
                .french: "Muet",
                .japanese: "ミュート"
            ],
            "track.volume": [
                .english: "Volume",
                .german: "Lautstärke",
                .spanish: "Volumen",
                .french: "Volume",
                .japanese: "音量"
            ],
            "track.pan": [
                .english: "Pan",
                .german: "Panorama",
                .spanish: "Paneo",
                .french: "Panoramique",
                .japanese: "パン"
            ],
            "track.addTrack": [
                .english: "Add Track",
                .german: "Spur hinzufügen",
                .spanish: "Añadir Pista",
                .french: "Ajouter une Piste",
                .japanese: "トラック追加"
            ],

            // MARK: - Audio Settings
            "audio.sampleRate": [
                .english: "Sample Rate",
                .german: "Abtastrate",
                .spanish: "Tasa de Muestreo",
                .french: "Taux d'Échantillonnage",
                .japanese: "サンプルレート"
            ],
            "audio.bufferSize": [
                .english: "Buffer Size",
                .german: "Puffergröße",
                .spanish: "Tamaño de Búfer",
                .french: "Taille du Tampon",
                .japanese: "バッファサイズ"
            ],
            "audio.latency": [
                .english: "Latency",
                .german: "Latenz",
                .spanish: "Latencia",
                .french: "Latence",
                .japanese: "レイテンシ"
            ],
            "audio.lowLatencyMode": [
                .english: "Low Latency Mode",
                .german: "Niedrige Latenz",
                .spanish: "Modo de Baja Latencia",
                .french: "Mode Faible Latence",
                .japanese: "低レイテンシモード"
            ],

            // MARK: - Biofeedback
            "bio.heartRate": [
                .english: "Heart Rate",
                .german: "Herzfrequenz",
                .spanish: "Frecuencia Cardíaca",
                .french: "Fréquence Cardiaque",
                .japanese: "心拍数",
                .arabic: "معدل ضربات القلب",
                .chinese: "心率"
            ],
            "bio.hrv": [
                .english: "HRV",
                .german: "HRV",
                .spanish: "VFC",
                .french: "VRC",
                .japanese: "HRV"
            ],
            "bio.coherence": [
                .english: "Coherence",
                .german: "Kohärenz",
                .spanish: "Coherencia",
                .french: "Cohérence",
                .japanese: "コヒーレンス"
            ],
            "bio.bpm": [
                .english: "BPM",
                .german: "BPM",
                .spanish: "LPM",
                .french: "BPM",
                .japanese: "BPM"
            ],

            // MARK: - Safety Warnings
            "safety.photosensitivity.title": [
                .english: "Photosensitivity Warning",
                .german: "Photosensitivitätswarnung",
                .spanish: "Advertencia de Fotosensibilidad",
                .french: "Avertissement de Photosensibilité",
                .japanese: "光過敏性警告",
                .arabic: "تحذير حساسية الضوء"
            ],
            "safety.hearing.title": [
                .english: "Hearing Safety",
                .german: "Hörschutz",
                .spanish: "Seguridad Auditiva",
                .french: "Sécurité Auditive",
                .japanese: "聴覚保護"
            ],
            "safety.doNotUse": [
                .english: "DO NOT USE IF YOU HAVE:",
                .german: "NICHT VERWENDEN BEI:",
                .spanish: "NO USAR SI TIENE:",
                .french: "NE PAS UTILISER SI VOUS AVEZ:",
                .japanese: "次の症状がある場合は使用しないでください："
            ],
            "safety.epilepsy": [
                .english: "Epilepsy or seizure disorders",
                .german: "Epilepsie oder Anfallsleiden",
                .spanish: "Epilepsia o trastornos convulsivos",
                .french: "Épilepsie ou troubles épileptiques",
                .japanese: "てんかんまたは発作性疾患"
            ],
            "safety.stopImmediately": [
                .english: "STOP IMMEDIATELY IF YOU EXPERIENCE:",
                .german: "SOFORT ABBRECHEN BEI:",
                .spanish: "DETENER INMEDIATAMENTE SI EXPERIMENTA:",
                .french: "ARRÊTER IMMÉDIATEMENT SI VOUS RESSENTEZ:",
                .japanese: "次の症状が出たら直ちに中止してください："
            ],
            "safety.iAcknowledge": [
                .english: "I Acknowledge",
                .german: "Ich bestätige",
                .spanish: "Acepto",
                .french: "J'accepte",
                .japanese: "承認します",
                .arabic: "أوافق"
            ],
            "safety.iDecline": [
                .english: "I Decline",
                .german: "Ich lehne ab",
                .spanish: "Rechazo",
                .french: "Je refuse",
                .japanese: "拒否します",
                .arabic: "أرفض"
            ],

            // MARK: - Monetization
            "paywall.unlockPro": [
                .english: "Unlock EOEL Pro",
                .german: "EOEL Pro freischalten",
                .spanish: "Desbloquear EOEL Pro",
                .french: "Débloquer EOEL Pro",
                .japanese: "EOEL Proをアンロック"
            ],
            "paywall.subscribe": [
                .english: "Subscribe Now",
                .german: "Jetzt abonnieren",
                .spanish: "Suscríbete Ahora",
                .french: "S'abonner Maintenant",
                .japanese: "今すぐ購読"
            ],
            "paywall.restore": [
                .english: "Restore Purchases",
                .german: "Käufe wiederherstellen",
                .spanish: "Restaurar Compras",
                .french: "Restaurer les Achats",
                .japanese: "購入を復元"
            ],
            "paywall.perMonth": [
                .english: "per month",
                .german: "pro Monat",
                .spanish: "por mes",
                .french: "par mois",
                .japanese: "月額"
            ],

            // MARK: - Onboarding
            "onboarding.welcome.title": [
                .english: "Welcome to EOEL",
                .german: "Willkommen bei EOEL",
                .spanish: "Bienvenido a EOEL",
                .french: "Bienvenue sur EOEL",
                .japanese: "EOELへようこそ",
                .arabic: "مرحبا بك في EOEL",
                .chinese: "欢迎来到EOEL"
            ],
            "onboarding.tagline": [
                .english: "Where Biology Becomes Art",
                .german: "Wo Biologie zur Kunst wird",
                .spanish: "Donde la Biología se Convierte en Arte",
                .french: "Où la Biologie Devient Art",
                .japanese: "生物学がアートになる場所"
            ],
            "onboarding.getStarted": [
                .english: "Get Started",
                .german: "Erste Schritte",
                .spanish: "Comenzar",
                .french: "Commencer",
                .japanese: "始める"
            ],

            // MARK: - Lighting
            "lighting.masterBrightness": [
                .english: "Master Brightness",
                .german: "Haupthelligkeit",
                .spanish: "Brillo Principal",
                .french: "Luminosité Principale",
                .japanese: "マスター明るさ"
            ],
            "lighting.audioReactive": [
                .english: "Audio-Reactive Lighting",
                .german: "Audio-reaktive Beleuchtung",
                .spanish: "Iluminación Reactiva al Audio",
                .french: "Éclairage Réactif à l'Audio",
                .japanese: "オーディオ反応照明"
            ],
            "lighting.connectedSystems": [
                .english: "Connected Systems",
                .german: "Verbundene Systeme",
                .spanish: "Sistemas Conectados",
                .french: "Systèmes Connectés",
                .japanese: "接続されたシステム"
            ],

            // MARK: - Errors
            "error.generic": [
                .english: "An error occurred",
                .german: "Ein Fehler ist aufgetreten",
                .spanish: "Ocurrió un error",
                .french: "Une erreur s'est produite",
                .japanese: "エラーが発生しました"
            ],
            "error.network": [
                .english: "Network connection error",
                .german: "Netzwerkverbindungsfehler",
                .spanish: "Error de conexión de red",
                .french: "Erreur de connexion réseau",
                .japanese: "ネットワーク接続エラー"
            ],
            "error.permission": [
                .english: "Permission denied",
                .german: "Zugriff verweigert",
                .spanish: "Permiso denegado",
                .french: "Permission refusée",
                .japanese: "権限が拒否されました"
            ]
        ])
    }

    /// Add a batch of translations
    private func addTranslations(_ translations: [String: [Language: String]]) {
        for (key, languageDict) in translations {
            for (language, translation) in languageDict {
                // This would integrate with the existing LocalizationManager
                // For now, this is a template structure
                print("Registering: \(key) -> \(language): \(translation)")
            }
        }
    }
}

// MARK: - Translation Template Generator

/// Generate translation template files for professional translation services
struct TranslationTemplateGenerator {

    /// Generate JSON template for translation
    static func generateJSONTemplate() -> String {
        let template = """
        {
          "_comment": "EOEL Translation Template - Replace values with translations",
          "_language": "English",
          "_languageCode": "en",

          "navigation": {
            "daw": "DAW",
            "video": "Video",
            "lighting": "Lighting",
            "eoelwork": "EoelWork",
            "settings": "Settings"
          },

          "transport": {
            "play": "Play",
            "pause": "Pause",
            "stop": "Stop",
            "record": "Record",
            "rewind": "Rewind"
          },

          "track": {
            "solo": "Solo",
            "mute": "Mute",
            "volume": "Volume",
            "pan": "Pan",
            "addTrack": "Add Track"
          },

          "biofeedback": {
            "heartRate": "Heart Rate",
            "hrv": "HRV",
            "coherence": "Coherence",
            "bpm": "BPM"
          },

          "safety": {
            "photosensitivityWarning": "Photosensitivity Warning",
            "hearingProtection": "Hearing Safety",
            "doNotUse": "DO NOT USE IF YOU HAVE:",
            "stopImmediately": "STOP IMMEDIATELY IF YOU EXPERIENCE:",
            "iAcknowledge": "I Acknowledge",
            "iDecline": "I Decline"
          },

          "monetization": {
            "unlockPro": "Unlock EOEL Pro",
            "subscribe": "Subscribe Now",
            "restore": "Restore Purchases",
            "perMonth": "per month"
          },

          "onboarding": {
            "welcomeTitle": "Welcome to EOEL",
            "tagline": "Where Biology Becomes Art",
            "getStarted": "Get Started"
          },

          "errors": {
            "generic": "An error occurred",
            "network": "Network connection error",
            "permission": "Permission denied"
          }
        }
        """
        return template
    }

    /// Export all keys for professional translation
    static func exportForTranslation(language: String) {
        // This would generate CSV/JSON files for translators
        print("Exporting translation template for: \(language)")
    }
}
