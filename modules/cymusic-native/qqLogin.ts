import { NativeModule, requireOptionalNativeModule } from 'expo'

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

// Optional so a stale sideloaded binary or unsupported platform disables QQ login
// instead of throwing during JS module initialization and terminating the app.
export default requireOptionalNativeModule<CyMusicQqLogin>('CyMusicQqLogin')
