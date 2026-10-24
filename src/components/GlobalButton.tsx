import { MaterialCommunityIcons } from '@expo/vector-icons'
import { router } from 'expo-router'
import React, { useCallback, useEffect, useState } from 'react'
import { useThemeColors } from '@/hooks/useAppTheme'
import { Alert } from 'react-native'
import CyMusicQqLogin, {
	type QqLoginCompletedEvent,
} from '../../modules/cymusic-native/qqLogin'
import { showToast } from '@/utils/utils'
import HeaderIconButton from './HeaderIconButton'

const GlobalButton = () => {
	const colors = useThemeColors()
	const [signedIn, setSignedIn] = useState(false)

	const openSettings = () => {
		router.navigate('/(modals)/settingModal')
	}

	const refreshLoginState = useCallback(async () => {
		setSignedIn(Boolean(await CyMusicQqLogin.getSession()))
	}, [])

	useEffect(() => {
		void refreshLoginState()
		const subscription = CyMusicQqLogin.addListener(
			'loginCompleted',
			(event: QqLoginCompletedEvent) => {
				if (event.ok) {
					setSignedIn(true)
					showToast('QQ 登录成功')
				} else if (!event.cancelled) {
					showToast('QQ 登录失败', event.message, 'error')
				}
			},
		)
		return () => subscription.remove()
	}, [refreshLoginState])

	const openQqLogin = async () => {
		try {
			await CyMusicQqLogin.startLogin()
		} catch (error) {
			showToast('无法打开 QQ 登录', error instanceof Error ? error.message : String(error), 'error')
		}
	}

	const handleAccount = () => {
		if (!signedIn) {
			void openQqLogin()
			return
		}
		Alert.alert('QQ 音乐账号', '登录状态已安全保存在本机。', [
			{ text: '取消', style: 'cancel' },
			{
				text: '退出登录',
				style: 'destructive',
				onPress: async () => {
					await CyMusicQqLogin.clearSession()
					setSignedIn(false)
					showToast('已退出 QQ 音乐')
				},
			},
			{ text: '重新登录', onPress: () => void openQqLogin() },
		])
	}

	return (
		<>
			<HeaderIconButton
				accessibilityLabel={signedIn ? 'QQ 音乐账号已登录' : '登录 QQ 音乐'}
				onPress={handleAccount}
			>
				<MaterialCommunityIcons
					name={signedIn ? 'account-circle' : 'account-circle-outline'}
					size={25}
					color={signedIn ? colors.primary : colors.icon}
				/>
			</HeaderIconButton>
			<HeaderIconButton accessibilityLabel="更多" onPress={openSettings}>
				<MaterialCommunityIcons name="menu" size={25} color={colors.icon} />
			</HeaderIconButton>
		</>
	)
}

export default GlobalButton
