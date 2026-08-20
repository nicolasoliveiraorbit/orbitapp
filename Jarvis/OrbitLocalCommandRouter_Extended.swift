import Foundation

// MARK: - Orbit Local Command Router
//
// Objetivo:
// - Responder comandos previsíveis em poucos milissegundos.
// - Evitar enviar tudo ao Qwen.
// - Acionar funções do aplicativo diretamente.
// - Usar o Qwen apenas como fallback.
//
// Arquitetura sugerida:
// Whisper.cpp -> OrbitLocalCommandRouter -> Kokoro
//                                   \-> Qwen apenas quando necessário

final class OrbitLocalCommandRouter {

    // MARK: - Public Types

    struct Match {
        let intentID: String
        let response: String
        let confidence: Double
        let action: Action
        let extractedValue: String?
    }

    enum Action: Equatable {
        case none

        // Navegação
        case openHome
        case openDemands
        case openCompletedDemands
        case openPendingDemands
        case openSettings
        case openChat
        case openRecorder
        case openTranscription
        case openFiles
        case openSearch
        case openCalendar
        case openQuickCapture

        // Demandas
        case createDemand
        case createDemandWithTitle(String)
        case openDemand(String)
        case listDemands
        case listPendingDemands
        case listCompletedDemands
        case completeCurrentDemand
        case deleteCurrentDemand
        case archiveCurrentDemand
        case editCurrentDemand
        case duplicateCurrentDemand
        case addNoteToCurrentDemand(String?)
        case addAttachmentToCurrentDemand
        case setCurrentDemandPriority(String)
        case setCurrentDemandDeadline(String?)
        case searchDemands(String?)

        // Áudio e transcrição
        case startRecording
        case stopRecording
        case pauseRecording
        case resumeRecording
        case startTranscription
        case stopTranscription
        case copyTranscription
        case clearTranscription
        case saveTranscription
        case exportTranscription
        case summarizeTranscription
        case createDemandsFromTranscription

        // Conversa
        case clearConversation
        case repeatLastResponse
        case stopSpeaking
        case speakSlower
        case speakFaster
        case increaseVolume
        case decreaseVolume
        case muteVoice
        case unmuteVoice

        // Sistema
        case showStatus
        case checkLocalModels
        case checkStorage
        case checkMemory
        case checkBattery
        case toggleOfflineMode
        case enableOfflineMode
        case disableOfflineMode
        case quitApplication
        case minimizeApplication
        case maximizeApplication

        // Conteúdo
        case copyLastResponse
        case saveLastResponse
        case exportLastResponse
        case summarizeClipboard
        case rewriteClipboard
        case correctClipboard
        case translateClipboard
    }

    struct Intent {
        let id: String
        let examples: [String]
        let keywords: Set<String>
        let minimumConfidence: Double
        let actionBuilder: (_ originalText: String, _ normalizedText: String) -> Action
        let responseBuilder: (_ originalText: String, _ normalizedText: String) -> String
        let extractedValueBuilder: ((_ originalText: String, _ normalizedText: String) -> String?)?
    }

    // MARK: - Configuration

    private let globalMinimumConfidence: Double
    private let exactPhraseBonus: Double = 1.0
    private let containedPhraseScore: Double = 0.92
    private let exampleWeight: Double = 0.74
    private let keywordWeight: Double = 0.26

    private lazy var intents: [Intent] = buildIntents()

    init(globalMinimumConfidence: Double = 0.60) {
        self.globalMinimumConfidence = globalMinimumConfidence
    }

    // MARK: - Public API

    func response(for text: String) -> Match? {
        let normalizedInput = normalize(text)

        guard !normalizedInput.isEmpty else {
            return Match(
                intentID: "empty_input",
                response: "Não entendi o comando.",
                confidence: 1.0,
                action: .none,
                extractedValue: nil
            )
        }

        if let demandTitle = Self.extractOpenDemandTitle(original: text, normalized: normalizedInput) {
            return Match(
                intentID: "open_demand_by_title",
                response: "Abrindo a demanda \(demandTitle).",
                confidence: 1.0,
                action: .openDemand(demandTitle),
                extractedValue: demandTitle
            )
        }

        var bestMatch: Match?

        for intent in intents {
            let confidence = score(input: normalizedInput, intent: intent)
            let requiredConfidence = max(globalMinimumConfidence, intent.minimumConfidence)

            guard confidence >= requiredConfidence else {
                continue
            }

            let candidate = Match(
                intentID: intent.id,
                response: intent.responseBuilder(text, normalizedInput),
                confidence: confidence,
                action: intent.actionBuilder(text, normalizedInput),
                extractedValue: intent.extractedValueBuilder?(text, normalizedInput)
            )

            if bestMatch == nil || candidate.confidence > bestMatch!.confidence {
                bestMatch = candidate
            }
        }

        return bestMatch
    }

    func answerOrNil(_ text: String) -> String? {
        response(for: text)?.response
    }

    func shouldUseQwen(for text: String) -> Bool {
        response(for: text) == nil
    }

    // MARK: - Intent Factory

    private func makeIntent(
        id: String,
        examples: [String],
        keywords: [String],
        minimumConfidence: Double = 0.62,
        action: @escaping (_ originalText: String, _ normalizedText: String) -> Action = { _, _ in .none },
        response: @escaping (_ originalText: String, _ normalizedText: String) -> String,
        extractedValue: ((_ originalText: String, _ normalizedText: String) -> String?)? = nil
    ) -> Intent {
        Intent(
            id: id,
            examples: examples,
            keywords: Set(keywords.map(normalize)),
            minimumConfidence: minimumConfidence,
            actionBuilder: action,
            responseBuilder: response,
            extractedValueBuilder: extractedValue
        )
    }

    // MARK: - Intents

    private func buildIntents() -> [Intent] {
        var result: [Intent] = []

        // MARK: Saudações

        result.append(makeIntent(
            id: "greeting_general",
            examples: [
                "oi orbit", "olá orbit", "ola orbit", "e aí orbit", "e ai orbit",
                "fala orbit", "hey orbit", "orbit", "bom dia orbit",
                "boa tarde orbit", "boa noite orbit", "tudo bem orbit",
                "como vai orbit", "olá assistente", "oi assistente"
            ],
            keywords: ["oi", "ola", "orbit", "assistente", "bom", "dia", "boa", "tarde", "noite"],
            response: { _, _ in "Olá. Como posso ajudar?" }
        ))

        result.append(makeIntent(
            id: "greeting_morning",
            examples: [
                "bom dia", "bom dia orbit", "um bom dia", "dia orbit",
                "acordei orbit", "começando o dia"
            ],
            keywords: ["bom", "dia", "orbit"],
            minimumConfidence: 0.68,
            response: { _, _ in "Bom dia. O sistema está pronto." }
        ))

        result.append(makeIntent(
            id: "greeting_afternoon",
            examples: [
                "boa tarde", "boa tarde orbit", "tarde orbit",
                "uma boa tarde", "começando a tarde"
            ],
            keywords: ["boa", "tarde", "orbit"],
            minimumConfidence: 0.68,
            response: { _, _ in "Boa tarde. O sistema está pronto." }
        ))

        result.append(makeIntent(
            id: "greeting_evening",
            examples: [
                "boa noite", "boa noite orbit", "noite orbit",
                "uma boa noite", "começando a noite"
            ],
            keywords: ["boa", "noite", "orbit"],
            minimumConfidence: 0.68,
            response: { _, _ in "Boa noite. O sistema está pronto." }
        ))

        // MARK: Identidade e capacidades

        result.append(makeIntent(
            id: "identity",
            examples: [
                "quem é você", "quem e voce", "qual é o seu nome", "qual e seu nome",
                "como você se chama", "como voce se chama", "você é a orbit",
                "voce e a orbit", "quem é a orbit", "quem e a orbit",
                "se apresente", "apresente-se", "diga quem você é"
            ],
            keywords: ["quem", "voce", "nome", "chama", "orbit", "apresente"],
            response: { _, _ in "Eu sou a EVA, sua assistente de voz local." }
        ))

        result.append(makeIntent(
            id: "capabilities",
            examples: [
                "o que você pode fazer", "o que voce pode fazer",
                "quais são suas funções", "quais sao suas funcoes",
                "como você pode me ajudar", "como voce pode me ajudar",
                "o que a orbit faz", "o que você sabe fazer",
                "me mostre suas funções", "liste suas funções",
                "quais comandos você entende", "o que posso pedir"
            ],
            keywords: ["pode", "fazer", "funcoes", "ajudar", "comandos", "entende", "orbit"],
            response: { _, _ in
                "Posso controlar funções do Orbit, organizar demandas, transcrever áudio, responder comandos locais e consultar o modelo de inteligência artificial quando necessário."
            }
        ))

        result.append(makeIntent(
            id: "help",
            examples: [
                "ajuda", "me ajude", "preciso de ajuda", "mostrar comandos",
                "mostre os comandos", "lista de comandos", "o que posso falar",
                "como usar a orbit", "como eu uso você", "como usar você"
            ],
            keywords: ["ajuda", "ajude", "comandos", "mostrar", "usar", "lista"],
            response: { _, _ in
                "Você pode pedir para abrir telas, criar demandas, iniciar gravações, transcrever áudio, consultar hora e data ou executar ações do aplicativo."
            }
        ))

        result.append(makeIntent(
            id: "creator",
            examples: [
                "quem te criou", "quem criou você", "quem criou a orbit",
                "quem é seu criador", "quem te desenvolveu", "quem desenvolveu a orbit"
            ],
            keywords: ["quem", "criou", "criador", "desenvolveu", "orbit"],
            response: { _, _ in "Eu fui criada para funcionar dentro do Orbit." }
        ))

        // MARK: Hora, data e calendário

        result.append(makeIntent(
            id: "current_time",
            examples: [
                "que horas são", "que horas sao", "me diga as horas",
                "qual é o horário", "qual e o horario", "horas agora",
                "hora atual", "me fala a hora", "diga a hora",
                "qual a hora", "você sabe que horas são"
            ],
            keywords: ["horas", "hora", "horario", "agora", "atual"],
            response: { _, _ in
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "pt_BR")
                formatter.dateFormat = "HH:mm"
                return "Agora são \(formatter.string(from: Date()))."
            }
        ))

        result.append(makeIntent(
            id: "current_date",
            examples: [
                "que dia é hoje", "que dia e hoje", "qual é a data de hoje",
                "qual e a data de hoje", "me diga a data", "data atual",
                "qual a data", "me fala a data", "hoje é que dia",
                "em que dia estamos", "diga o dia de hoje"
            ],
            keywords: ["dia", "data", "hoje", "atual"],
            response: { _, _ in
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "pt_BR")
                formatter.dateFormat = "EEEE, d 'de' MMMM 'de' yyyy"
                return "Hoje é \(formatter.string(from: Date()))."
            }
        ))

        result.append(makeIntent(
            id: "weekday",
            examples: [
                "que dia da semana é hoje", "qual o dia da semana",
                "hoje é segunda", "que dia da semana estamos",
                "me diga o dia da semana"
            ],
            keywords: ["dia", "semana", "hoje"],
            minimumConfidence: 0.66,
            response: { _, _ in
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "pt_BR")
                formatter.dateFormat = "EEEE"
                return "Hoje é \(formatter.string(from: Date()))."
            }
        ))

        result.append(makeIntent(
            id: "open_calendar",
            examples: [
                "abrir calendário", "abra o calendário", "mostrar calendário",
                "ir para o calendário", "ver calendário", "exibir calendário",
                "abre minha agenda", "mostrar agenda", "ver agenda"
            ],
            keywords: ["abrir", "calendario", "agenda", "mostrar", "ver"],
            action: { _, _ in .openCalendar },
            response: { _, _ in "Abrindo o calendário." }
        ))

        // MARK: Navegação

        result.append(makeIntent(
            id: "open_home",
            examples: [
                "abrir início", "abrir inicio", "voltar para o início",
                "voltar para o inicio", "ir para a tela inicial",
                "mostrar tela inicial", "abrir home", "voltar para home",
                "abrir janela do orbit", "abra a janela principal", "mostrar janela do orbit",
                "trazer orbit para frente", "abrir painel principal"
            ],
            keywords: ["abrir", "inicio", "home", "tela", "inicial", "voltar", "janela", "orbit", "principal", "painel"],
            action: { _, _ in .openHome },
            response: { _, _ in "Abrindo a janela principal do Orbit." }
        ))

        result.append(makeIntent(
            id: "open_demands",
            examples: [
                "abrir demandas", "abra as demandas", "mostrar demandas",
                "mostrar minhas demandas", "ir para demandas", "ver demandas",
                "exibir tarefas", "abrir tarefas", "mostrar tarefas",
                "ir para minhas tarefas", "listar demandas"
            ],
            keywords: ["abrir", "mostrar", "demandas", "tarefas", "exibir", "listar"],
            action: { _, _ in .openDemands },
            response: { _, _ in "Abrindo suas demandas." }
        ))

        result.append(makeIntent(
            id: "open_pending_demands",
            examples: [
                "abrir demandas pendentes", "mostrar pendências",
                "mostrar demandas pendentes", "ver tarefas pendentes",
                "listar o que falta", "mostrar o que está pendente",
                "abrir tarefas em aberto", "ver demandas em aberto"
            ],
            keywords: ["abrir", "mostrar", "demandas", "pendentes", "pendencias", "tarefas", "aberto"],
            action: { _, _ in .openPendingDemands },
            response: { _, _ in "Abrindo as demandas pendentes." }
        ))

        result.append(makeIntent(
            id: "open_completed_demands",
            examples: [
                "abrir demandas concluídas", "mostrar tarefas concluídas",
                "ver demandas finalizadas", "listar tarefas prontas",
                "mostrar o que foi concluído", "abrir concluídas",
                "ver demandas completas"
            ],
            keywords: ["abrir", "mostrar", "demandas", "concluidas", "finalizadas", "prontas"],
            action: { _, _ in .openCompletedDemands },
            response: { _, _ in "Abrindo as demandas concluídas." }
        ))

        result.append(makeIntent(
            id: "open_settings",
            examples: [
                "abrir configurações", "abra as configurações",
                "ir para configurações", "mostrar preferências",
                "abrir preferências", "configurar orbit",
                "abrir ajustes", "mostrar ajustes",
                "abrir janela de configurações", "abrir painel sobre",
                "abrir sobre", "mostrar sobre o orbit"
            ],
            keywords: ["abrir", "configuracoes", "preferencias", "ajustes", "configurar", "janela", "painel", "sobre", "orbit"],
            action: { _, _ in .openSettings },
            response: { _, _ in "Abrindo as configurações." }
        ))

        result.append(makeIntent(
            id: "open_chat",
            examples: [
                "abrir conversa", "abrir chat", "conversar com a orbit",
                "mostrar o chat", "ir para o chat", "abrir assistente",
                "mostrar conversa", "abrir inteligência artificial",
                "abrir janela do chat", "abrir painel da eva"
            ],
            keywords: ["abrir", "chat", "conversa", "conversar", "assistente", "inteligencia", "janela", "painel", "eva"],
            action: { _, _ in .openChat },
            response: { _, _ in "Abrindo a conversa." }
        ))

        result.append(makeIntent(
            id: "open_recorder",
            examples: [
                "abrir gravador", "abra o gravador", "mostrar gravador",
                "ir para gravação", "abrir gravação", "tela de gravação",
                "quero gravar áudio", "abrir áudio",
                "abrir janela de áudio", "abrir painel de áudio"
            ],
            keywords: ["abrir", "gravador", "gravacao", "gravar", "audio"],
            action: { _, _ in .openRecorder },
            response: { _, _ in "Abrindo o gravador." }
        ))

        result.append(makeIntent(
            id: "open_transcription",
            examples: [
                "abrir transcrição", "abra a transcrição",
                "mostrar transcrição", "ir para transcrição",
                "ver texto transcrito", "abrir texto do áudio",
                "mostrar resultado da transcrição"
            ],
            keywords: ["abrir", "transcricao", "mostrar", "texto", "audio"],
            action: { _, _ in .openTranscription },
            response: { _, _ in "Abrindo a transcrição." }
        ))

        result.append(makeIntent(
            id: "open_files",
            examples: [
                "abrir arquivos", "mostrar arquivos", "ir para arquivos",
                "ver anexos", "abrir anexos", "mostrar documentos",
                "abrir documentos", "listar arquivos"
            ],
            keywords: ["abrir", "arquivos", "anexos", "documentos", "listar"],
            action: { _, _ in .openFiles },
            response: { _, _ in "Abrindo os arquivos." }
        ))

        result.append(makeIntent(
            id: "open_search",
            examples: [
                "abrir busca", "abrir pesquisa", "mostrar busca",
                "procurar", "ir para pesquisa", "abrir campo de busca",
                "quero pesquisar"
            ],
            keywords: ["abrir", "busca", "pesquisa", "procurar", "pesquisar"],
            action: { _, _ in .openSearch },
            response: { _, _ in "Abrindo a busca." }
        ))

        result.append(makeIntent(
            id: "open_quick_capture",
            examples: [
                "abrir acesso rápido", "abrir acesso rapido", "abra o acesso rápido",
                "abrir janela de captura", "abrir captura rápida", "abrir captura rapida",
                "nova demanda em janela", "abrir janela de nova demanda"
            ],
            keywords: ["abrir", "acesso", "rapido", "janela", "captura", "nova", "demanda"],
            action: { _, _ in .openQuickCapture },
            response: { _, _ in "Abrindo o acesso rápido." }
        ))

        // MARK: Demandas

        result.append(makeIntent(
            id: "create_demand",
            examples: [
                "criar uma demanda", "crie uma demanda", "nova demanda",
                "adicionar demanda", "adicionar tarefa", "criar tarefa",
                "nova tarefa", "registrar demanda", "quero criar uma demanda",
                "abrir nova demanda"
            ],
            keywords: ["criar", "nova", "demanda", "adicionar", "tarefa", "registrar"],
            action: { _, _ in .createDemand },
            response: { _, _ in "Certo. Diga o título da nova demanda." }
        ))

        result.append(makeIntent(
            id: "create_demand_with_title",
            examples: [
                "criar demanda chamada", "crie uma demanda chamada",
                "nova demanda chamada", "adicionar tarefa chamada",
                "criar tarefa com o nome", "registre uma demanda chamada"
            ],
            keywords: ["criar", "demanda", "chamada", "tarefa", "nome"],
            minimumConfidence: 0.70,
            action: { original, normalized in
                let title = Self.extractAfterTriggers(
                    original: original,
                    normalized: normalized,
                    triggers: [
                        "criar demanda chamada",
                        "crie uma demanda chamada",
                        "nova demanda chamada",
                        "adicionar tarefa chamada",
                        "criar tarefa com o nome",
                        "registre uma demanda chamada"
                    ]
                ) ?? "Nova demanda"
                return .createDemandWithTitle(title)
            },
            response: { original, normalized in
                let title = Self.extractAfterTriggers(
                    original: original,
                    normalized: normalized,
                    triggers: [
                        "criar demanda chamada",
                        "crie uma demanda chamada",
                        "nova demanda chamada",
                        "adicionar tarefa chamada",
                        "criar tarefa com o nome",
                        "registre uma demanda chamada"
                    ]
                ) ?? "Nova demanda"
                return "Criando a demanda \(title)."
            },
            extractedValue: { original, normalized in
                Self.extractAfterTriggers(
                    original: original,
                    normalized: normalized,
                    triggers: [
                        "criar demanda chamada",
                        "crie uma demanda chamada",
                        "nova demanda chamada",
                        "adicionar tarefa chamada",
                        "criar tarefa com o nome",
                        "registre uma demanda chamada"
                    ]
                )
            }
        ))

        result.append(makeIntent(
            id: "open_demand_by_title",
            examples: [
                "abrir demanda orçamento", "abra a demanda contrato",
                "mostrar demanda reunião", "mostre a demanda pagamentos",
                "ir para demanda revisão", "abrir tarefa cliente",
                "mostrar tarefa proposta"
            ],
            keywords: ["abrir", "abra", "mostrar", "mostre", "demanda", "tarefa", "ir"],
            minimumConfidence: 0.70,
            action: { original, normalized in
                guard let title = Self.extractAfterTriggers(
                    original: original,
                    normalized: normalized,
                    triggers: [
                        "abrir demanda",
                        "abra demanda",
                        "abra a demanda",
                        "mostrar demanda",
                        "mostre demanda",
                        "mostre a demanda",
                        "ir para demanda",
                        "abrir tarefa",
                        "abra tarefa",
                        "mostrar tarefa",
                        "mostre tarefa"
                    ]
                ) else {
                    return .openDemands
                }
                return .openDemand(title)
            },
            response: { original, normalized in
                guard let title = Self.extractAfterTriggers(
                    original: original,
                    normalized: normalized,
                    triggers: [
                        "abrir demanda",
                        "abra demanda",
                        "abra a demanda",
                        "mostrar demanda",
                        "mostre demanda",
                        "mostre a demanda",
                        "ir para demanda",
                        "abrir tarefa",
                        "abra tarefa",
                        "mostrar tarefa",
                        "mostre tarefa"
                    ]
                ) else {
                    return "Abrindo suas demandas."
                }
                return "Abrindo a demanda \(title)."
            },
            extractedValue: { original, normalized in
                Self.extractAfterTriggers(
                    original: original,
                    normalized: normalized,
                    triggers: [
                        "abrir demanda",
                        "abra demanda",
                        "abra a demanda",
                        "mostrar demanda",
                        "mostre demanda",
                        "mostre a demanda",
                        "ir para demanda",
                        "abrir tarefa",
                        "abra tarefa",
                        "mostrar tarefa",
                        "mostre tarefa"
                    ]
                )
            }
        ))

        result.append(makeIntent(
            id: "list_demands",
            examples: [
                "listar demandas", "liste as demandas", "mostrar todas as demandas",
                "quais são minhas demandas", "quais sao minhas demandas",
                "ler minhas demandas", "me diga minhas tarefas",
                "mostrar lista de tarefas"
            ],
            keywords: ["listar", "demandas", "mostrar", "tarefas", "lista"],
            action: { _, _ in .listDemands },
            response: { _, _ in "Listando todas as demandas." }
        ))

        result.append(makeIntent(
            id: "list_pending_demands",
            examples: [
                "listar demandas pendentes", "quais tarefas estão pendentes",
                "o que falta fazer", "me diga o que falta",
                "mostrar pendências", "listar tarefas em aberto",
                "quais demandas ainda não terminei"
            ],
            keywords: ["listar", "pendentes", "tarefas", "falta", "aberto", "demandas"],
            action: { _, _ in .listPendingDemands },
            response: { _, _ in "Listando as demandas pendentes." }
        ))

        result.append(makeIntent(
            id: "list_completed_demands",
            examples: [
                "listar demandas concluídas", "quais tarefas foram concluídas",
                "mostrar tarefas finalizadas", "ver o que já terminei",
                "listar demandas prontas", "mostrar concluídas"
            ],
            keywords: ["listar", "concluidas", "tarefas", "finalizadas", "terminei", "prontas"],
            action: { _, _ in .listCompletedDemands },
            response: { _, _ in "Listando as demandas concluídas." }
        ))

        result.append(makeIntent(
            id: "complete_current_demand",
            examples: [
                "concluir demanda", "marcar demanda como concluída",
                "finalizar demanda", "terminar essa tarefa",
                "marcar como pronta", "concluir tarefa atual",
                "essa demanda está pronta", "finalize esta demanda"
            ],
            keywords: ["concluir", "demanda", "finalizar", "terminar", "pronta", "tarefa"],
            action: { _, _ in .completeCurrentDemand },
            response: { _, _ in "Marcando a demanda como concluída." }
        ))

        result.append(makeIntent(
            id: "delete_current_demand",
            examples: [
                "excluir demanda", "apagar demanda", "deletar demanda",
                "remover tarefa", "excluir tarefa atual", "apague esta demanda",
                "remova essa tarefa", "delete a demanda"
            ],
            keywords: ["excluir", "apagar", "deletar", "remover", "demanda", "tarefa"],
            minimumConfidence: 0.72,
            action: { _, _ in .deleteCurrentDemand },
            response: { _, _ in "Preparando a exclusão da demanda atual." }
        ))

        result.append(makeIntent(
            id: "archive_current_demand",
            examples: [
                "arquivar demanda", "arquive esta demanda", "mandar para o arquivo",
                "arquivar tarefa atual", "guardar esta demanda",
                "mover demanda para arquivo"
            ],
            keywords: ["arquivar", "arquivo", "demanda", "tarefa", "guardar"],
            action: { _, _ in .archiveCurrentDemand },
            response: { _, _ in "Arquivando a demanda atual." }
        ))

        result.append(makeIntent(
            id: "edit_current_demand",
            examples: [
                "editar demanda", "alterar demanda", "modificar tarefa",
                "editar tarefa atual", "mudar essa demanda",
                "abrir edição da demanda", "corrigir demanda"
            ],
            keywords: ["editar", "alterar", "modificar", "mudar", "demanda", "tarefa"],
            action: { _, _ in .editCurrentDemand },
            response: { _, _ in "Abrindo a edição da demanda." }
        ))

        result.append(makeIntent(
            id: "duplicate_current_demand",
            examples: [
                "duplicar demanda", "copiar demanda", "criar cópia da tarefa",
                "duplicar tarefa atual", "copiar esta demanda",
                "fazer uma cópia dessa demanda"
            ],
            keywords: ["duplicar", "copiar", "copia", "demanda", "tarefa"],
            action: { _, _ in .duplicateCurrentDemand },
            response: { _, _ in "Duplicando a demanda atual." }
        ))

        result.append(makeIntent(
            id: "add_note_to_demand",
            examples: [
                "adicionar nota", "adicionar observação", "colocar uma observação",
                "anotar na demanda", "adicionar comentário", "incluir nota",
                "escrever observação na tarefa"
            ],
            keywords: ["adicionar", "nota", "observacao", "anotar", "comentario", "demanda"],
            action: { original, normalized in
                let note = Self.extractAfterTriggers(
                    original: original,
                    normalized: normalized,
                    triggers: [
                        "adicionar nota",
                        "adicionar observacao",
                        "colocar uma observacao",
                        "anotar na demanda",
                        "adicionar comentario",
                        "incluir nota"
                    ]
                )
                return .addNoteToCurrentDemand(note)
            },
            response: { _, _ in "Adicionando uma observação à demanda." }
        ))

        result.append(makeIntent(
            id: "add_attachment",
            examples: [
                "adicionar anexo", "anexar arquivo", "colocar um arquivo na demanda",
                "adicionar documento", "anexar documento", "incluir imagem",
                "adicionar foto à demanda"
            ],
            keywords: ["adicionar", "anexo", "anexar", "arquivo", "documento", "imagem", "foto"],
            action: { _, _ in .addAttachmentToCurrentDemand },
            response: { _, _ in "Abrindo a seleção de arquivos." }
        ))

        result.append(makeIntent(
            id: "set_priority_high",
            examples: [
                "marcar prioridade alta", "definir como urgente",
                "essa demanda é urgente", "colocar prioridade alta",
                "tarefa urgente", "marcar como importante",
                "prioridade máxima"
            ],
            keywords: ["prioridade", "alta", "urgente", "importante", "maxima"],
            action: { _, _ in .setCurrentDemandPriority("alta") },
            response: { _, _ in "Definindo prioridade alta." }
        ))

        result.append(makeIntent(
            id: "set_priority_medium",
            examples: [
                "marcar prioridade média", "definir prioridade média",
                "colocar prioridade normal", "prioridade intermediária",
                "essa tarefa é normal"
            ],
            keywords: ["prioridade", "media", "normal", "intermediaria"],
            action: { _, _ in .setCurrentDemandPriority("média") },
            response: { _, _ in "Definindo prioridade média." }
        ))

        result.append(makeIntent(
            id: "set_priority_low",
            examples: [
                "marcar prioridade baixa", "definir prioridade baixa",
                "essa tarefa não é urgente", "colocar como baixa prioridade",
                "pouca prioridade"
            ],
            keywords: ["prioridade", "baixa", "pouca", "urgente"],
            action: { _, _ in .setCurrentDemandPriority("baixa") },
            response: { _, _ in "Definindo prioridade baixa." }
        ))

        result.append(makeIntent(
            id: "set_deadline",
            examples: [
                "definir prazo", "adicionar prazo", "colocar data limite",
                "definir vencimento", "adicionar data de entrega",
                "marcar prazo para", "essa tarefa vence"
            ],
            keywords: ["definir", "prazo", "data", "limite", "vencimento", "entrega", "vence"],
            action: { original, normalized in
                let value = Self.extractAfterTriggers(
                    original: original,
                    normalized: normalized,
                    triggers: [
                        "definir prazo",
                        "adicionar prazo",
                        "colocar data limite",
                        "definir vencimento",
                        "adicionar data de entrega",
                        "marcar prazo para",
                        "essa tarefa vence"
                    ]
                )
                return .setCurrentDemandDeadline(value)
            },
            response: { _, _ in "Definindo o prazo da demanda." }
        ))

        result.append(makeIntent(
            id: "search_demands",
            examples: [
                "buscar demanda", "procurar demanda", "pesquisar tarefa",
                "encontrar demanda", "buscar nas tarefas",
                "pesquisar demandas por", "procurar tarefa chamada"
            ],
            keywords: ["buscar", "procurar", "pesquisar", "encontrar", "demanda", "tarefa"],
            action: { original, normalized in
                let query = Self.extractAfterTriggers(
                    original: original,
                    normalized: normalized,
                    triggers: [
                        "buscar demanda",
                        "procurar demanda",
                        "pesquisar tarefa",
                        "encontrar demanda",
                        "buscar nas tarefas",
                        "pesquisar demandas por",
                        "procurar tarefa chamada"
                    ]
                )
                return .searchDemands(query)
            },
            response: { _, _ in "Pesquisando nas demandas." }
        ))

        // MARK: Gravação

        result.append(makeIntent(
            id: "start_recording",
            examples: [
                "começar gravação", "iniciar gravação", "gravar agora",
                "comece a gravar", "inicie o gravador", "gravar áudio",
                "começar a capturar áudio", "pode gravar",
                "aperte gravar", "inicia a gravação"
            ],
            keywords: ["comecar", "iniciar", "gravacao", "gravar", "audio"],
            action: { _, _ in .startRecording },
            response: { _, _ in "Iniciando a gravação." }
        ))

        result.append(makeIntent(
            id: "stop_recording",
            examples: [
                "parar gravação", "encerrar gravação", "finalizar gravação",
                "pare de gravar", "pode parar de gravar", "interromper gravação",
                "termine a gravação", "parar o áudio"
            ],
            keywords: ["parar", "encerrar", "finalizar", "gravacao", "gravar", "audio"],
            action: { _, _ in .stopRecording },
            response: { _, _ in "Encerrando a gravação." }
        ))

        result.append(makeIntent(
            id: "pause_recording",
            examples: [
                "pausar gravação", "pause a gravação", "dar pausa na gravação",
                "interromper temporariamente", "pausar áudio", "segurar gravação"
            ],
            keywords: ["pausar", "pause", "gravacao", "audio", "temporariamente"],
            action: { _, _ in .pauseRecording },
            response: { _, _ in "Pausando a gravação." }
        ))

        result.append(makeIntent(
            id: "resume_recording",
            examples: [
                "continuar gravação", "retomar gravação", "voltar a gravar",
                "continue gravando", "retome o áudio", "seguir com a gravação"
            ],
            keywords: ["continuar", "retomar", "voltar", "gravacao", "gravar", "audio"],
            action: { _, _ in .resumeRecording },
            response: { _, _ in "Retomando a gravação." }
        ))

        // MARK: Transcrição

        result.append(makeIntent(
            id: "start_transcription",
            examples: [
                "iniciar transcrição", "começar transcrição", "transcrever áudio",
                "transcreva este áudio", "começar a transcrever",
                "converter áudio em texto", "transformar áudio em texto",
                "rodar transcrição", "pode transcrever"
            ],
            keywords: ["iniciar", "comecar", "transcricao", "transcrever", "audio", "texto"],
            action: { _, _ in .startTranscription },
            response: { _, _ in "Iniciando a transcrição." }
        ))

        result.append(makeIntent(
            id: "stop_transcription",
            examples: [
                "parar transcrição", "cancelar transcrição",
                "interromper transcrição", "pare de transcrever",
                "encerrar transcrição", "cancelar conversão"
            ],
            keywords: ["parar", "cancelar", "interromper", "transcricao", "transcrever"],
            action: { _, _ in .stopTranscription },
            response: { _, _ in "Interrompendo a transcrição." }
        ))

        result.append(makeIntent(
            id: "copy_transcription",
            examples: [
                "copiar transcrição", "copie a transcrição",
                "copiar texto transcrito", "copiar resultado",
                "mandar transcrição para área de transferência",
                "copiar todo o texto"
            ],
            keywords: ["copiar", "transcricao", "texto", "resultado", "transferencia"],
            action: { _, _ in .copyTranscription },
            response: { _, _ in "Copiando a transcrição." }
        ))

        result.append(makeIntent(
            id: "clear_transcription",
            examples: [
                "limpar transcrição", "apagar transcrição",
                "remover texto transcrito", "zerar transcrição",
                "limpar o texto", "apague o resultado"
            ],
            keywords: ["limpar", "apagar", "remover", "transcricao", "texto", "resultado"],
            action: { _, _ in .clearTranscription },
            response: { _, _ in "Limpando a transcrição." }
        ))

        result.append(makeIntent(
            id: "save_transcription",
            examples: [
                "salvar transcrição", "salve a transcrição",
                "guardar texto transcrito", "salvar resultado",
                "gravar transcrição", "armazenar transcrição"
            ],
            keywords: ["salvar", "guardar", "transcricao", "texto", "resultado", "armazenar"],
            action: { _, _ in .saveTranscription },
            response: { _, _ in "Salvando a transcrição." }
        ))

        result.append(makeIntent(
            id: "export_transcription",
            examples: [
                "exportar transcrição", "exporte a transcrição",
                "gerar arquivo da transcrição", "baixar transcrição",
                "salvar transcrição em arquivo", "exportar texto"
            ],
            keywords: ["exportar", "arquivo", "transcricao", "texto", "gerar"],
            action: { _, _ in .exportTranscription },
            response: { _, _ in "Exportando a transcrição." }
        ))

        result.append(makeIntent(
            id: "summarize_transcription",
            examples: [
                "resumir transcrição", "faça um resumo da transcrição",
                "resuma o texto transcrito", "criar resumo do áudio",
                "resumir esse áudio", "gerar resumo"
            ],
            keywords: ["resumir", "resumo", "transcricao", "texto", "audio"],
            action: { _, _ in .summarizeTranscription },
            response: { _, _ in "Preparando o resumo da transcrição." }
        ))

        result.append(makeIntent(
            id: "create_demands_from_transcription",
            examples: [
                "criar demandas da transcrição", "gerar tarefas do áudio",
                "extrair demandas do texto", "transformar transcrição em demandas",
                "identificar tarefas no áudio", "criar tarefas da gravação",
                "gerar demandas automaticamente"
            ],
            keywords: ["criar", "gerar", "demandas", "tarefas", "transcricao", "audio", "extrair"],
            action: { _, _ in .createDemandsFromTranscription },
            response: { _, _ in "Analisando a transcrição para criar demandas." }
        ))

        // MARK: Voz

        result.append(makeIntent(
            id: "repeat_last_response",
            examples: [
                "repita", "pode repetir", "fale de novo", "diga novamente",
                "repita a última resposta", "não ouvi", "fala outra vez",
                "repete isso", "repete por favor"
            ],
            keywords: ["repita", "repetir", "novo", "novamente", "ouvi", "vez"],
            action: { _, _ in .repeatLastResponse },
            response: { _, _ in "" }
        ))

        result.append(makeIntent(
            id: "stop_speaking",
            examples: [
                "pare de falar", "fica quieta", "silêncio", "silencio",
                "cala a boca", "parar voz", "interromper fala",
                "chega", "pare agora"
            ],
            keywords: ["parar", "pare", "falar", "silencio", "voz", "interromper"],
            minimumConfidence: 0.72,
            action: { _, _ in .stopSpeaking },
            response: { _, _ in "" }
        ))

        result.append(makeIntent(
            id: "speak_slower",
            examples: [
                "fale mais devagar", "fala mais devagar", "reduzir velocidade da voz",
                "diminua a velocidade", "voz mais lenta", "falar devagar"
            ],
            keywords: ["fale", "fala", "devagar", "reduzir", "velocidade", "lenta"],
            action: { _, _ in .speakSlower },
            response: { _, _ in "Reduzindo a velocidade da voz." }
        ))

        result.append(makeIntent(
            id: "speak_faster",
            examples: [
                "fale mais rápido", "fala mais rapido", "aumentar velocidade da voz",
                "acelere a fala", "voz mais rápida", "falar rápido"
            ],
            keywords: ["fale", "fala", "rapido", "aumentar", "velocidade", "acelerar"],
            action: { _, _ in .speakFaster },
            response: { _, _ in "Aumentando a velocidade da voz." }
        ))

        result.append(makeIntent(
            id: "increase_volume",
            examples: [
                "aumentar volume", "aumente o volume", "fale mais alto",
                "subir volume", "voz mais alta", "deixe mais alto"
            ],
            keywords: ["aumentar", "volume", "alto", "subir", "voz"],
            action: { _, _ in .increaseVolume },
            response: { _, _ in "Aumentando o volume." }
        ))

        result.append(makeIntent(
            id: "decrease_volume",
            examples: [
                "diminuir volume", "abaixe o volume", "fale mais baixo",
                "reduzir volume", "voz mais baixa", "deixe mais baixo"
            ],
            keywords: ["diminuir", "abaixar", "volume", "baixo", "reduzir", "voz"],
            action: { _, _ in .decreaseVolume },
            response: { _, _ in "Diminuindo o volume." }
        ))

        result.append(makeIntent(
            id: "mute_voice",
            examples: [
                "desativar voz", "silenciar voz", "ficar sem voz",
                "não fale mais", "modo silencioso", "desligar voz"
            ],
            keywords: ["desativar", "silenciar", "voz", "silencioso", "desligar"],
            action: { _, _ in .muteVoice },
            response: { _, _ in "" }
        ))

        result.append(makeIntent(
            id: "unmute_voice",
            examples: [
                "ativar voz", "voltar a falar", "ligar voz",
                "tirar do silencioso", "habilitar fala", "pode falar"
            ],
            keywords: ["ativar", "voltar", "falar", "ligar", "voz", "habilitar"],
            action: { _, _ in .unmuteVoice },
            response: { _, _ in "Voz ativada." }
        ))

        // MARK: Conversa

        result.append(makeIntent(
            id: "clear_conversation",
            examples: [
                "limpar conversa", "apagar conversa", "zerar conversa",
                "limpar histórico", "apagar histórico do chat",
                "nova conversa", "começar conversa nova"
            ],
            keywords: ["limpar", "apagar", "zerar", "conversa", "historico", "nova"],
            action: { _, _ in .clearConversation },
            response: { _, _ in "Limpando a conversa." }
        ))

        result.append(makeIntent(
            id: "copy_last_response",
            examples: [
                "copiar resposta", "copie sua resposta",
                "copiar última resposta", "mandar resposta para área de transferência",
                "copie esse texto", "copiar o que você disse"
            ],
            keywords: ["copiar", "resposta", "texto", "disse", "transferencia"],
            action: { _, _ in .copyLastResponse },
            response: { _, _ in "Copiando a última resposta." }
        ))

        result.append(makeIntent(
            id: "save_last_response",
            examples: [
                "salvar resposta", "salve sua resposta",
                "guardar última resposta", "salvar esse texto",
                "registrar resposta", "guardar o que você disse"
            ],
            keywords: ["salvar", "guardar", "resposta", "texto", "registrar"],
            action: { _, _ in .saveLastResponse },
            response: { _, _ in "Salvando a última resposta." }
        ))

        result.append(makeIntent(
            id: "export_last_response",
            examples: [
                "exportar resposta", "exporte a resposta",
                "criar arquivo com a resposta", "salvar resposta em arquivo",
                "exportar esse texto", "gerar arquivo da resposta"
            ],
            keywords: ["exportar", "resposta", "arquivo", "texto", "gerar"],
            action: { _, _ in .exportLastResponse },
            response: { _, _ in "Exportando a última resposta." }
        ))

        // MARK: Clipboard

        result.append(makeIntent(
            id: "summarize_clipboard",
            examples: [
                "resumir área de transferência", "resuma o texto copiado",
                "resumir clipboard", "faça um resumo do que copiei",
                "resumir conteúdo copiado", "resuma minha área de transferência"
            ],
            keywords: ["resumir", "resumo", "copiado", "clipboard", "transferencia", "texto"],
            action: { _, _ in .summarizeClipboard },
            response: { _, _ in "Resumindo o texto copiado." }
        ))

        result.append(makeIntent(
            id: "rewrite_clipboard",
            examples: [
                "reescrever texto copiado", "reescreva a área de transferência",
                "melhorar texto copiado", "refazer o texto",
                "reescrever clipboard", "melhore o que eu copiei"
            ],
            keywords: ["reescrever", "reescreva", "melhorar", "texto", "copiado", "clipboard"],
            action: { _, _ in .rewriteClipboard },
            response: { _, _ in "Reescrevendo o texto copiado." }
        ))

        result.append(makeIntent(
            id: "correct_clipboard",
            examples: [
                "corrigir texto copiado", "corrija a área de transferência",
                "corrigir português", "corrigir gramática do texto",
                "revisar texto copiado", "corrigir erros do clipboard"
            ],
            keywords: ["corrigir", "corrija", "portugues", "gramatica", "texto", "copiado", "revisar"],
            action: { _, _ in .correctClipboard },
            response: { _, _ in "Corrigindo o texto copiado." }
        ))

        result.append(makeIntent(
            id: "translate_clipboard",
            examples: [
                "traduzir texto copiado", "traduza a área de transferência",
                "traduzir clipboard", "traduza o que eu copiei",
                "converter texto para outro idioma", "traduzir conteúdo copiado"
            ],
            keywords: ["traduzir", "traduza", "texto", "copiado", "clipboard", "idioma"],
            action: { _, _ in .translateClipboard },
            response: { _, _ in "Traduzindo o texto copiado." }
        ))

        // MARK: Status do sistema

        result.append(makeIntent(
            id: "status",
            examples: [
                "você está funcionando", "voce esta funcionando",
                "está tudo funcionando", "qual é o seu status",
                "qual e seu status", "orbit está online",
                "sistema funcionando", "verificar status",
                "como está o sistema"
            ],
            keywords: ["funcionando", "status", "online", "orbit", "sistema"],
            action: { _, _ in .showStatus },
            response: { _, _ in "O sistema está funcionando normalmente." }
        ))

        result.append(makeIntent(
            id: "check_models",
            examples: [
                "verificar modelos", "checar modelos locais",
                "os modelos estão funcionando", "status do qwen",
                "status do kokoro", "verificar inteligência artificial",
                "checar modelo de voz", "checar modelo de linguagem"
            ],
            keywords: ["verificar", "checar", "modelos", "qwen", "kokoro", "voz", "linguagem"],
            action: { _, _ in .checkLocalModels },
            response: { _, _ in "Verificando os modelos locais." }
        ))

        result.append(makeIntent(
            id: "check_storage",
            examples: [
                "verificar armazenamento", "quanto espaço tenho",
                "espaço disponível", "ver uso do disco",
                "quanto espaço livre", "checar armazenamento"
            ],
            keywords: ["armazenamento", "espaco", "disco", "livre", "verificar", "checar"],
            action: { _, _ in .checkStorage },
            response: { _, _ in "Verificando o armazenamento disponível." }
        ))

        result.append(makeIntent(
            id: "check_memory",
            examples: [
                "verificar memória", "quanto de memória está usando",
                "uso de ram", "memória disponível", "checar ram",
                "quanto de memória livre"
            ],
            keywords: ["memoria", "ram", "uso", "disponivel", "livre", "checar"],
            action: { _, _ in .checkMemory },
            response: { _, _ in "Verificando o uso de memória." }
        ))

        result.append(makeIntent(
            id: "check_battery",
            examples: [
                "verificar bateria", "quanto de bateria tenho",
                "nível da bateria", "porcentagem da bateria",
                "bateria atual", "checar bateria"
            ],
            keywords: ["bateria", "nivel", "porcentagem", "atual", "checar"],
            action: { _, _ in .checkBattery },
            response: { _, _ in "Verificando a bateria." }
        ))

        result.append(makeIntent(
            id: "enable_offline_mode",
            examples: [
                "ativar modo offline", "ligar modo offline",
                "usar somente modelos locais", "ficar offline",
                "desativar internet da orbit", "modo totalmente local"
            ],
            keywords: ["ativar", "ligar", "offline", "local", "internet"],
            action: { _, _ in .enableOfflineMode },
            response: { _, _ in "Ativando o modo offline." }
        ))

        result.append(makeIntent(
            id: "disable_offline_mode",
            examples: [
                "desativar modo offline", "sair do modo offline",
                "permitir internet", "voltar para modo online",
                "ligar recursos online", "desligar modo local"
            ],
            keywords: ["desativar", "sair", "offline", "internet", "online", "local"],
            action: { _, _ in .disableOfflineMode },
            response: { _, _ in "Desativando o modo offline." }
        ))

        // MARK: Janela e aplicativo

        result.append(makeIntent(
            id: "minimize_application",
            examples: [
                "minimizar orbit", "minimize o aplicativo",
                "minimizar janela", "esconder janela",
                "mandar para o dock", "reduzir janela"
            ],
            keywords: ["minimizar", "aplicativo", "janela", "esconder", "dock", "reduzir"],
            action: { _, _ in .minimizeApplication },
            response: { _, _ in "Minimizando o Orbit." }
        ))

        result.append(makeIntent(
            id: "maximize_application",
            examples: [
                "maximizar orbit", "maximize o aplicativo",
                "aumentar janela", "colocar em tela cheia",
                "expandir janela", "abrir em tela cheia"
            ],
            keywords: ["maximizar", "aplicativo", "janela", "tela", "cheia", "expandir"],
            action: { _, _ in .maximizeApplication },
            response: { _, _ in "Maximizando o Orbit." }
        ))

        result.append(makeIntent(
            id: "quit_application",
            examples: [
                "fechar orbit", "encerrar orbit", "sair do aplicativo",
                "fechar aplicativo", "encerrar o programa",
                "desligar orbit", "pode fechar"
            ],
            keywords: ["fechar", "encerrar", "sair", "aplicativo", "programa", "orbit"],
            minimumConfidence: 0.74,
            action: { _, _ in .quitApplication },
            response: { _, _ in "Encerrando o Orbit." }
        ))

        // MARK: Confirmações e respostas sociais curtas

        result.append(makeIntent(
            id: "thanks",
            examples: [
                "obrigado", "obrigada", "muito obrigado", "muito obrigada",
                "valeu", "agradeço", "perfeito obrigado", "beleza valeu",
                "ótimo obrigado", "show valeu"
            ],
            keywords: ["obrigado", "obrigada", "valeu", "agradeco", "perfeito", "otimo"],
            minimumConfidence: 0.70,
            response: { _, _ in "Certo." }
        ))

        result.append(makeIntent(
            id: "confirmation_yes",
            examples: [
                "sim", "pode", "confirmar", "confirmo", "isso",
                "exatamente", "correto", "pode fazer", "vai em frente",
                "continua", "prossiga"
            ],
            keywords: ["sim", "confirmar", "confirmo", "correto", "continua", "prossiga"],
            minimumConfidence: 0.78,
            response: { _, _ in "Confirmado." }
        ))

        result.append(makeIntent(
            id: "confirmation_no",
            examples: [
                "não", "nao", "cancelar", "não faça", "deixa pra lá",
                "esquece", "pare", "não precisa", "cancela isso"
            ],
            keywords: ["nao", "cancelar", "esquece", "pare", "precisa"],
            minimumConfidence: 0.80,
            response: { _, _ in "Cancelado." }
        ))

        result.append(makeIntent(
            id: "goodbye",
            examples: [
                "tchau", "até mais", "ate mais", "até depois",
                "até logo", "encerrar conversa", "finalizar conversa",
                "falou", "até amanhã", "boa noite tchau"
            ],
            keywords: ["tchau", "ate", "mais", "depois", "logo", "encerrar", "finalizar"],
            response: { _, _ in "Conversa encerrada." }
        ))

        result.append(makeIntent(
            id: "how_are_you",
            examples: [
                "como você está", "como voce esta", "tudo bem com você",
                "como vai", "você está bem", "como estão as coisas"
            ],
            keywords: ["como", "voce", "esta", "bem", "vai", "coisas"],
            response: { _, _ in "Estou funcionando normalmente." }
        ))

        // MARK: Respostas locais simples

        result.append(makeIntent(
            id: "yes_no_are_you_local",
            examples: [
                "você funciona localmente", "voce funciona localmente",
                "você roda offline", "voce roda offline",
                "a orbit é local", "a orbit funciona sem internet",
                "você precisa de internet"
            ],
            keywords: ["funciona", "localmente", "offline", "local", "internet", "orbit"],
            response: { _, _ in
                "Parte das funções pode rodar localmente. Comandos previsíveis não precisam do modelo de linguagem."
            }
        ))

        result.append(makeIntent(
            id: "latency_explanation",
            examples: [
                "por que está lento", "por que você demora",
                "por que a resposta demora", "por que o qwen demora",
                "por que leva tanto tempo", "de onde vem a lentidão"
            ],
            keywords: ["lento", "demora", "resposta", "qwen", "tempo", "lentidao"],
            response: { _, _ in
                "A maior parte da latência vem da geração do modelo de linguagem e da síntese de voz. Comandos locais evitam essa etapa."
            }
        ))

        result.append(makeIntent(
            id: "privacy",
            examples: [
                "meus dados ficam locais", "isso é privado",
                "você envia meus dados", "a orbit manda dados para internet",
                "minhas conversas saem do computador", "como funciona a privacidade"
            ],
            keywords: ["dados", "locais", "privado", "envia", "internet", "conversas", "privacidade"],
            response: { _, _ in
                "Quando o modo local está ativo, o processamento pode permanecer no computador, dependendo das integrações habilitadas."
            }
        ))

        result.append(makeIntent(
            id: "wake_word_acknowledgement",
            examples: [
                "orbit você está aí", "orbit está me ouvindo",
                "você está me ouvindo", "consegue me ouvir",
                "está ouvindo", "orbit responde"
            ],
            keywords: ["orbit", "ouvindo", "ouvir", "responde"],
            response: { _, _ in "Estou ouvindo." }
        ))

        return result
    }

    // MARK: - Matching

    private func score(input: String, intent: Intent) -> Double {
        let inputTokens = Set(tokenize(input))

        guard !inputTokens.isEmpty else {
            return 0
        }

        var bestExampleScore = 0.0

        for example in intent.examples {
            let normalizedExample = normalize(example)

            if input == normalizedExample {
                return exactPhraseBonus
            }

            if input.contains(normalizedExample) || normalizedExample.contains(input) {
                bestExampleScore = max(bestExampleScore, containedPhraseScore)
            }

            let exampleTokens = Set(tokenize(normalizedExample))
            let similarity = jaccardSimilarity(inputTokens, exampleTokens)
            bestExampleScore = max(bestExampleScore, similarity)
        }

        let keywordHits = inputTokens.intersection(intent.keywords).count
        let keywordScore: Double

        if intent.keywords.isEmpty {
            keywordScore = 0
        } else {
            keywordScore = Double(keywordHits) / Double(intent.keywords.count)
        }

        let lengthPenalty = tokenLengthPenalty(
            inputTokens: inputTokens,
            examples: intent.examples
        )

        return min(
            1.0,
            ((bestExampleScore * exampleWeight) + (keywordScore * keywordWeight)) * lengthPenalty
        )
    }

    private func tokenLengthPenalty(
        inputTokens: Set<String>,
        examples: [String]
    ) -> Double {
        let exampleTokenCounts = examples.map { Set(tokenize($0)).count }
        let nearestDistance = exampleTokenCounts
            .map { abs($0 - inputTokens.count) }
            .min() ?? 0

        switch nearestDistance {
        case 0...2:
            return 1.0
        case 3...5:
            return 0.96
        default:
            return 0.90
        }
    }

    private func jaccardSimilarity(
        _ lhs: Set<String>,
        _ rhs: Set<String>
    ) -> Double {
        let union = lhs.union(rhs)

        guard !union.isEmpty else {
            return 0
        }

        let intersection = lhs.intersection(rhs)
        return Double(intersection.count) / Double(union.count)
    }

    // MARK: - Text Processing

    private func normalize(_ text: String) -> String {
        text
            .folding(
                options: [.diacriticInsensitive, .caseInsensitive],
                locale: Locale(identifier: "pt_BR")
            )
            .lowercased()
            .replacingOccurrences(
                of: #"[^a-z0-9\s]"#,
                with: " ",
                options: .regularExpression
            )
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private func tokenize(_ text: String) -> [String] {
        normalize(text)
            .split(separator: " ")
            .map(String.init)
            .filter { !stopWords.contains($0) }
    }

    private let stopWords: Set<String> = [
        "a", "o", "as", "os",
        "de", "da", "do", "das", "dos",
        "e", "em", "um", "uma", "uns", "umas",
        "para", "por", "com", "sem",
        "me", "mim", "minha", "meu", "minhas", "meus",
        "seu", "sua", "seus", "suas",
        "voce", "voces",
        "porfavor", "favor",
        "que", "qual", "quais",
        "essa", "esse", "esta", "este",
        "isso", "aquilo",
        "agora"
    ]

    // MARK: - Extraction

    private static func extractOpenDemandTitle(original: String, normalized: String) -> String? {
        extractAfterTriggers(
            original: original,
            normalized: normalized,
            triggers: [
                "abrir demanda",
                "abra demanda",
                "abra a demanda",
                "mostrar demanda",
                "mostre demanda",
                "mostre a demanda",
                "ir para demanda",
                "abrir tarefa",
                "abra tarefa",
                "mostrar tarefa",
                "mostre tarefa"
            ]
        )
    }

    private static func extractAfterTriggers(
        original: String,
        normalized: String,
        triggers: [String]
    ) -> String? {
        let normalizedTriggers = triggers.map {
            $0.folding(
                options: [.diacriticInsensitive, .caseInsensitive],
                locale: Locale(identifier: "pt_BR")
            )
            .lowercased()
        }

        for trigger in normalizedTriggers {
            guard let normalizedRange = normalized.range(of: trigger) else {
                continue
            }

            let normalizedSuffix = normalized[normalizedRange.upperBound...]
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !normalizedSuffix.isEmpty else {
                continue
            }

            // Como a normalização pode alterar acentos e pontuação,
            // retorna o sufixo normalizado para máxima previsibilidade.
            return normalizedSuffix
        }

        return nil
    }
}

// MARK: - Integration Example

/*
final class OrbitAssistantService {

    private let localRouter = OrbitLocalCommandRouter()

    func processUserText(_ text: String) async -> String {
        if let localMatch = localRouter.response(for: text) {
            execute(localMatch.action)

            // Respostas vazias são úteis em ações como "pare de falar".
            return localMatch.response
        }

        return await sendToQwen(text)
    }

    private func execute(_ action: OrbitLocalCommandRouter.Action) {
        switch action {
        case .none:
            break

        case .openHome:
            NotificationCenter.default.post(name: .orbitOpenHome, object: nil)

        case .openDemands:
            NotificationCenter.default.post(name: .orbitOpenDemands, object: nil)

        case .createDemand:
            NotificationCenter.default.post(name: .orbitCreateDemand, object: nil)

        case .createDemandWithTitle(let title):
            NotificationCenter.default.post(
                name: .orbitCreateDemand,
                object: nil,
                userInfo: ["title": title]
            )

        case .startRecording:
            NotificationCenter.default.post(name: .orbitStartRecording, object: nil)

        case .stopRecording:
            NotificationCenter.default.post(name: .orbitStopRecording, object: nil)

        case .startTranscription:
            NotificationCenter.default.post(name: .orbitStartTranscription, object: nil)

        case .stopSpeaking:
            NotificationCenter.default.post(name: .orbitStopSpeaking, object: nil)

        default:
            // Implemente as demais ações conforme a arquitetura do Orbit.
            print("Ação local:", action)
        }
    }

    private func sendToQwen(_ text: String) async -> String {
        // Use a implementação atual do Orbit.
        return "Resposta gerada pelo Qwen."
    }
}

// MARK: - Optional Notification Names

extension Notification.Name {
    static let orbitOpenHome = Notification.Name("orbit.openHome")
    static let orbitOpenDemands = Notification.Name("orbit.openDemands")
    static let orbitCreateDemand = Notification.Name("orbit.createDemand")
    static let orbitStartRecording = Notification.Name("orbit.startRecording")
    static let orbitStopRecording = Notification.Name("orbit.stopRecording")
    static let orbitStartTranscription = Notification.Name("orbit.startTranscription")
    static let orbitStopSpeaking = Notification.Name("orbit.stopSpeaking")
}
*/
