import { FunctionComponent, FunctionController } from '@kit.AgentFrameworkKit';
import { common } from '@kit.AbilityKit';
import { salmonLogger } from 'salmonlogger';

const TAG = 'SweetAgentComponent'

@Component
export struct SweetAgentComponent {
  @Prop queryText: string = ''
  @Prop title: string = ''
  @State isAgentSupport: boolean = false
  private controller: FunctionController = new FunctionController()
  private agentId: string = 'agenta368cef7304a45a9a9e18935030de62e' // 智能体对应的 agent id，由小艺智能体平台在创建智能体时指定

  async aboutToAppear() {
    await this.checkAgentSupport()
    this.initListeners()
  }

  initListeners() {
    if (canIUse("SystemCapability.AI.Agent.AgentKit")) {
      this.controller?.on('agentDialogOpened', this.onAgentOpenedCallback)
      this.controller?.on('agentDialogClosed', this.onAgentClosedCallback)
    }
  }

  onAgentOpenedCallback = () => {
    console.error('test agent dialog opened callback' + this.queryText)
  }
  onAgentClosedCallback = () => {
    console.error('test agent dialog closed callback')
  }

  aboutToDisappear() {
    if (canIUse("SystemCapability.AI.Agent.AgentKit")) {
      this.controller?.off('agentDialogOpened')
      this.controller?.off('agentDialogClosed')
    }
  }

  async checkAgentSupport() {
    if (canIUse("SystemCapability.AI.Agent.AgentKit")) {
      try {
        let context = this.getUIContext()?.getHostContext() as common.UIAbilityContext
        this.isAgentSupport = await this.controller.isAgentSupport(context, this.agentId)
      } catch (err) {
        salmonLogger.addLog(TAG, `checkAgentSupport err: ${JSON.stringify(err)}, message: ${err.message}`, true)
      }
    }
  }

  build() {
    Column() {
      if (canIUse('SystemCapability.AI.Agent.AgentKit')) {
        if (this.isAgentSupport) {
          FunctionComponent({
            agentId: this.agentId,
            onError: (err: BusinessError) => {
              salmonLogger.addLog(TAG, `test err: ${JSON.stringify(err)}, message: ${err.message}`, true)
            },
            options: {
              title: this.title,
              queryText: this.queryText
            },
            controller: this.controller
          })
        }
      }
    }
  }
}