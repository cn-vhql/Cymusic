import { NativeModule, requireNativeModule } from 'expo'

export type QqLoginCompletedEvent = {
	ok: boolean
	cancelled?: boolean
	message?: string
}

declare class CyMusicQqLogin extends NativeModule<{
	loginCompleted: (event: QqLoginCompletedEvent) => void
}> {
	startLogin(): Promise<boolean>
	getSession(): Promise<string | null>
	clearSession(): Promise<void>
}

export default requireNativeModule<CyMusicQqLogin>('CyMusicQqLogin')
