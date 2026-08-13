# =============================================================================
# Functions.cmake — вспомогательные функции
# =============================================================================

function(print_file_list label var_name)
	if(DEFINED ${var_name} AND ${var_name})
		message(STATUS "${label}:")
		foreach(file ${${var_name}})
			file(RELATIVE_PATH rel_path "${CMAKE_SOURCE_DIR}" "${file}")
			message(STATUS "  ${rel_path}")
		endforeach()
	else()
		message(STATUS "${label}:")
		message(STATUS "  Empty")
	endif()
endfunction()

# =============================================================================

function(generate_deployment_scripts TARGET_NAME QML_DIR)
	find_program(WINDEPLOYQT_EXECUTABLE
			NAMES windeployqt windeployqt.exe
			HINTS ${CMAKE_PREFIX_PATH}/bin
			DOC "Path to windeployqt executable"
	)

	if(NOT WINDEPLOYQT_EXECUTABLE)
		message(WARNING "windeployqt not found. Deployment scripts will not be generated.")
		return()
	endif()

	set(EXE_PATH "${CMAKE_BINARY_DIR}/src/${TARGET_NAME}${CMAKE_EXECUTABLE_SUFFIX}")

	if(NOT IS_DIRECTORY "${QML_DIR}")
		message(WARNING "QML directory '${QML_DIR}' not found. Scripts will be generated without --qmldir.")
		set(QML_DIR "")
	endif()

	configure_file(
			${CMAKE_SOURCE_DIR}/cmake/Deploy.bat.in
			${CMAKE_BINARY_DIR}/deploy_${TARGET_NAME}.bat
			@ONLY
	)

	configure_file(
			${CMAKE_SOURCE_DIR}/cmake/Deploy.sh.in
			${CMAKE_BINARY_DIR}/deploy_${TARGET_NAME}.sh
			@ONLY
	)

	if(UNIX)
		file(CHMOD ${CMAKE_BINARY_DIR}/deploy_${TARGET_NAME}.sh
				PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE
				GROUP_READ GROUP_EXECUTE
				WORLD_READ WORLD_EXECUTE)
	endif()

	message(STATUS "Deployment scripts generated in ${CMAKE_BINARY_DIR}:")
	message(STATUS "  ${CMAKE_BINARY_DIR}/deploy_${TARGET_NAME}.bat")
	message(STATUS "  ${CMAKE_BINARY_DIR}/deploy_${TARGET_NAME}.sh")

	if(WIN32)
		add_custom_target(deploy_${TARGET_NAME}
				COMMAND ${CMAKE_BINARY_DIR}/deploy_${TARGET_NAME}.bat
				DEPENDS ${TARGET_NAME}
				COMMENT "Running deployment script for ${TARGET_NAME}..."
				VERBATIM
		)
	else()
		add_custom_target(deploy_${TARGET_NAME}
				COMMAND ${CMAKE_BINARY_DIR}/deploy_${TARGET_NAME}.sh
				DEPENDS ${TARGET_NAME}
				COMMENT "Running deployment script for ${TARGET_NAME}..."
				VERBATIM
		)
	endif()

endfunction()
