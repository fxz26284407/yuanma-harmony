export interface AgentInfo {
  id: string;
  name: string;
  containerName: string;
  logo: Resource;
}

export const AGENTS: AgentInfo[] = [
  { id: 'codex', name: 'Codex', containerName: '项目', logo: $r('app.media.agent_codex') },
  { id: 'deepseek', name: 'DeepSeek', containerName: '工作区', logo: $r('app.media.agent_deepseek') }
];
export const DEFAULT_AGENT: AgentInfo = AGENTS[0];
export function findAgent(id: string): AgentInfo | undefined {
  return AGENTS.find((agent: AgentInfo) => agent.id === id);
}
