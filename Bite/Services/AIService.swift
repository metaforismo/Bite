import Foundation
import UIKit

enum AIServiceError: LocalizedError {
    case networkUnavailable
    case serverError(statusCode: Int)
    case rateLimited
    case invalidResponse
    case timeout

    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Connessione non disponibile. I tuoi dati sono salvati localmente."
        case .serverError(let code):
            return "Errore del server (\(code)). Riprova tra poco."
        case .rateLimited:
            return "Troppe richieste. Attendi qualche secondo."
        case .invalidResponse:
            return "Risposta non valida. Riprova."
        case .timeout:
            return "Timeout della richiesta. Controlla la connessione."
        }
    }
}

enum AIServiceStatus: Equatable, Sendable {
    case online
    case offline
    case degraded(String)
}

protocol AIServiceProtocol: Sendable {
    func analyzeFoodEntry(_ text: String) async throws -> (NutritionInfo, String?, [String]?)
    func analyzePhoto(_ image: UIImage, context: String?) async throws -> (String, NutritionInfo, String?, [String]?)
    func correctEntry(original: FoodEntry, correction: String) async throws -> (NutritionInfo, String?, [String]?)
    var status: AIServiceStatus { get }
}

final class MockAIService: AIServiceProtocol, @unchecked Sendable {
    var status: AIServiceStatus = .online

    private let mockDatabase: [String: (NutritionInfo, String, [String])] = [
        "big mac": (
            NutritionInfo(calories: 550, protein: 25, carbs: 45, fat: 30, fiber: 3, sugar: 9, sodium: 1010, confidenceLevel: .high),
            "Ho calcolato basandomi sui valori nutrizionali ufficiali McDonald's per un Big Mac standard (2 patties, salsa speciale, lattuga, formaggio, cipolla, cetrioli, panino con semi di sesamo).",
            ["mcdonalds.com/nutrition", "fatsecret.com/big-mac"]
        ),
        "pizza margherita": (
            NutritionInfo(calories: 250, protein: 12, carbs: 33, fat: 8, fiber: 2, sugar: 4, sodium: 500, confidenceLevel: .high),
            "Calcolato per una fetta standard di pizza margherita napoletana (~150g). Valori basati su mozzarella, pomodoro San Marzano e basilico fresco.",
            ["nutritionvalue.org/pizza-margherita"]
        ),
        "insalata caesar": (
            NutritionInfo(calories: 360, protein: 22, carbs: 12, fat: 26, fiber: 3, sugar: 2, sodium: 780, confidenceLevel: .high),
            "Caesar salad con pollo grigliato, parmigiano, crostini e dressing Caesar classico. Porzione standard da ristorante (~300g).",
            ["caloriecount.com/caesar-salad"]
        ),
        "cappuccino": (
            NutritionInfo(calories: 120, protein: 6, carbs: 10, fat: 6, fiber: 0, sugar: 10, sodium: 80, confidenceLevel: .high),
            "Cappuccino standard con latte intero (240ml). Senza zucchero aggiunto.",
            ["starbucks.com/nutrition"]
        ),
        "pasta carbonara": (
            NutritionInfo(calories: 480, protein: 20, carbs: 55, fat: 20, fiber: 2, sugar: 2, sodium: 620, confidenceLevel: .high),
            "Porzione standard di spaghetti alla carbonara (~350g) con guanciale, pecorino romano, uova e pepe nero.",
            ["ricetteclassiche.it/carbonara-nutrition"]
        ),
        "cornetto": (
            NutritionInfo(calories: 230, protein: 4, carbs: 30, fat: 11, fiber: 1, sugar: 12, sodium: 180, confidenceLevel: .high),
            "Cornetto vuoto da bar italiano (~60g). Se ripieno di crema o marmellata, aggiungere 80-120 kcal.",
            ["alimentipedia.it/cornetto"]
        ),
        "poke bowl": (
            NutritionInfo(calories: 520, protein: 32, carbs: 58, fat: 16, fiber: 5, sugar: 8, sodium: 850, confidenceLevel: .high),
            "Poke bowl medio con riso, salmone crudo, avocado, edamame e salsa di soia. Porzione standard da ristorante.",
            ["pokeworks.com/nutrition"]
        ),
        "tramezzino": (
            NutritionInfo(calories: 280, protein: 14, carbs: 28, fat: 13, fiber: 1, sugar: 3, sodium: 520, confidenceLevel: .high),
            "Tramezzino classico con prosciutto cotto e formaggio. Pane bianco senza crosta.",
            ["alimentipedia.it/tramezzino"]
        ),
    ]

    func analyzeFoodEntry(_ text: String) async throws -> (NutritionInfo, String?, [String]?) {
        try await Task.sleep(for: .milliseconds(.random(in: 400...1200)))

        let lowered = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        if lowered.isEmpty {
            throw AIServiceError.invalidResponse
        }

        for (key, value) in mockDatabase {
            if lowered.contains(key) {
                return (value.0, value.1, value.2)
            }
        }

        // Generate plausible data for unknown foods
        let hash = abs(lowered.hashValue)
        let cal = 150 + (hash % 500)
        let pro = Double(10 + (hash % 30))
        let carb = Double(15 + (hash % 60))
        let fat = Double(5 + (hash % 25))

        let nutrition = NutritionInfo(
            calories: cal,
            protein: pro,
            carbs: carb,
            fat: fat,
            confidenceLevel: .medium
        )
        let thought = "Ho stimato i valori nutrizionali per \"\(text)\" basandomi su alimenti simili nel database. Per risultati più precisi, specifica la porzione e il brand."

        return (nutrition, thought, nil)
    }

    func analyzePhoto(_ image: UIImage, context: String?) async throws -> (String, NutritionInfo, String?, [String]?) {
        try await Task.sleep(for: .milliseconds(.random(in: 800...2000)))

        let mockDescriptions: [(String, NutritionInfo, String)] = [
            ("Piatto di pasta al pomodoro con basilico", NutritionInfo(calories: 420, protein: 14, carbs: 68, fat: 10, fiber: 3, sugar: 6, sodium: 480, confidenceLevel: .medium),
             "Dalla foto riconosco un piatto di pasta con sugo di pomodoro e basilico fresco. Porzione stimata ~350g."),
            ("Insalata mista con pomodorini e mozzarella", NutritionInfo(calories: 280, protein: 16, carbs: 12, fat: 18, fiber: 4, sugar: 6, sodium: 420, confidenceLevel: .medium),
             "Dalla foto vedo un'insalata con pomodorini, mozzarella e verdure miste. Porzione media da ristorante."),
            ("Panino con prosciutto e formaggio", NutritionInfo(calories: 380, protein: 22, carbs: 36, fat: 16, fiber: 2, sugar: 4, sodium: 680, confidenceLevel: .medium),
             "Dalla foto riconosco un panino farcito con prosciutto e formaggio. Dimensione standard da bar.")
        ]

        let index = abs(image.hashValue) % mockDescriptions.count
        let (desc, nutrition, thought) = mockDescriptions[index]
        return (desc, nutrition, thought, ["analisi-foto-ai"])
    }

    func correctEntry(original: FoodEntry, correction: String) async throws -> (NutritionInfo, String?, [String]?) {
        try await Task.sleep(for: .milliseconds(.random(in: 400...1000)))

        let hash = abs(correction.lowercased().hashValue)
        let cal = 100 + (hash % 600)
        let pro = Double(8 + (hash % 35))
        let carb = Double(10 + (hash % 65))
        let fat = Double(3 + (hash % 28))

        let nutrition = NutritionInfo(
            calories: cal,
            protein: pro,
            carbs: carb,
            fat: fat,
            confidenceLevel: .medium
        )
        let thought = "Ho ricalcolato i valori dopo la correzione: \"\(correction)\". Basandomi sulla descrizione originale \"\(original.text)\" e applicando la modifica richiesta."

        return (nutrition, thought, nil)
    }
}
