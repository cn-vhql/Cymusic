import { router } from 'expo-router'
import React from 'react'
import { MaterialCommunityIcons } from '@expo/vector-icons'
import { useThemeColors } from '@/hooks/useAppTheme'
import HeaderIconButton from './HeaderIconButton'

const AddPlayListButton = () => {
	const colors = useThemeColors()

	const showPlayList = () => {
		router.navigate('/(modals)/importPlayList')
	}

	return (
		<HeaderIconButton accessibilityLabel="创建歌单" onPress={showPlayList}>
			<MaterialCommunityIcons
				name="plus"
				size={27}
				color={colors.icon}
			/>
		</HeaderIconButton>
	)
}

export default AddPlayListButton
