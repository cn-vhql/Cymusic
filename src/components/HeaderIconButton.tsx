import React, { type PropsWithChildren } from 'react'
import { Pressable, StyleSheet } from 'react-native'

// Current file: one fixed-size header action so iOS navigation titles and icons stay centered.
type HeaderIconButtonProps = PropsWithChildren<{
	accessibilityLabel: string
	onPress: () => void
}>

const HeaderIconButton = ({
	accessibilityLabel,
	onPress,
	children,
}: HeaderIconButtonProps) => (
	<Pressable
		accessibilityRole="button"
		accessibilityLabel={accessibilityLabel}
		onPress={onPress}
		style={({ pressed }) => [styles.button, pressed && styles.pressed]}
	>
		{children}
	</Pressable>
)

const styles = StyleSheet.create({
	button: {
		width: 44,
		height: 44,
		alignItems: 'center',
		justifyContent: 'center',
	},
	pressed: {
		opacity: 0.5,
	},
})

export default HeaderIconButton
