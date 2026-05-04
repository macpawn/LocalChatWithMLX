import Foundation
import LocalChatKit

let manager = ModelManager()
let selector = ModelSelector(manager: manager)

let loadedModel = await selector.run()
let session = ChatSession(model: loadedModel)
let runner = ChatRunner(session: session, modelName: loadedModel.model.displayName)
await runner.run()
