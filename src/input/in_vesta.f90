MODULE in_vesta
!
!
!**********************************************************************************
!*  IN_VESTA                                                                      *
!**********************************************************************************
!* This module reads files in VESTA format, described here:                       *
!*    http://jp-minerals.org/vesta/en/doc.html                                    *
!**********************************************************************************
!* (C) March 2016 - Pierre Hirel                                                  *
!*     Unité Matériaux Et Transformations (UMET),                                 *
!*     Université de Lille 1, Bâtiment C6, F-59655 Villeneuve D'Ascq (FRANCE)     *
!*     pierre.hirel@univ-lille1.fr                                                *
!* Last modification: P. Hirel - 03 May 2016                                      *
!**********************************************************************************
!* This program is free software: you can redistribute it and/or modify           *
!* it under the terms of the GNU General Public License as published by           *
!* the Free Software Foundation, either version 3 of the License, or              *
!* (at your option) any later version.                                            *
!*                                                                                *
!* This program is distributed in the hope that it will be useful,                *
!* but WITHOUT ANY WARRANTY; without even the implied warranty of                 *
!* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                  *
!* GNU General Public License for more details.                                   *
!*                                                                                *
!* You should have received a copy of the GNU General Public License              *
!* along with this program.  If not, see <http://www.gnu.org/licenses/>.          *
!**********************************************************************************
!
USE comv
USE constants
USE messages
USE files
USE subroutines
USE symops
!
!
CONTAINS
!
SUBROUTINE READ_VESTA(inputfile,H,P,comment,AUXNAMES,AUX)
!
IMPLICIT NONE
CHARACTER(LEN=*),INTENT(IN):: inputfile
CHARACTER(LEN=2):: species
CHARACTER(LEN=128):: msg, temp, temp2
CHARACTER(LEN=128):: sgroup
CHARACTER(LEN=128),DIMENSION(:),ALLOCATABLE,INTENT(OUT):: AUXNAMES !names of auxiliary properties
CHARACTER(LEN=128),DIMENSION(:),ALLOCATABLE,INTENT(OUT):: comment
LOGICAL:: fileexists  !does a file already exist?
INTEGER:: i, j
INTEGER:: NP  !number of atoms
INTEGER:: Nsym  !number of symmetry operations
INTEGER:: sgroupnum  !space group number
REAL(dp):: a, b, c, alpha, beta, gamma   !supercell (conventional notation)
REAL(dp):: occ    !site occupancy
REAL(dp):: P1, P2, P3
REAL(dp),DIMENSION(3,3),INTENT(OUT):: H   !Base vectors of the supercell
REAL(dp),DIMENSION(:,:),ALLOCATABLE,INTENT(OUT):: P   !Positions of atoms
REAL(dp),DIMENSION(:,:),ALLOCATABLE:: S   !Positions of shells (not used here)
REAL(dp),DIMENSION(:,:),ALLOCATABLE,INTENT(OUT):: AUX !auxiliary properties
REAL(dp),DIMENSION(12):: symops_line !line of symmetry operations list
!
!
!Initialize variables
sgroup = ""
i = 0
NP = 0
Nsym = 0
H(:,:) = 0.d0
ALLOCATE(comment(1))
 comment = ""
!
!
100 CONTINUE
WRITE(msg,*) 'entering READ_VESTA'
CALL ATOMSK_MSG(999,(/msg/),(/0.d0/))
!
OPEN(UNIT=30,FILE=inputfile,FORM='FORMATTED',STATUS='OLD')
REWIND(30)
!
!Parse the file a first time to count number of atoms
DO
  READ(30,'(a128)',END=200,ERR=200) temp
  temp = ADJUSTL(temp)
  !
  IF( temp(1:5)=="TITLE" ) THEN
    READ(30,'(a128)',END=110,ERR=110) comment(1)
    comment(1) = ADJUSTL(comment(1))
  !
  ELSEIF( temp(1:5)=="CELLP" ) THEN
    READ(30,'(a128)',END=801,ERR=801) temp
    temp = ADJUSTL(temp)
    READ(temp,*,END=801,ERR=801) a, b, c, alpha, beta, gamma
    alpha = DEG2RAD(alpha)
    beta  = DEG2RAD(beta)
    gamma = DEG2RAD(gamma)
    CALL CONVMAT(a,b,c,alpha,beta,gamma,H)
    !
  ELSEIF( temp(1:5)=="STRUC" ) THEN
    !Count atoms
    DO WHILE( temp(1:5).NE."0 0 0" )
      READ(30,'(a128)',END=800,ERR=800) temp
      temp = ADJUSTL(temp)
      READ(temp,*,END=200,ERR=200) i
      IF( i>NP ) NP=i
      READ(30,'(a128)',END=200,ERR=200) temp2
    ENDDO
    !
  ELSEIF( temp(1:5)=="GROUP" ) THEN
    !Read space group number in following line
    READ(30,'(a128)',END=801,ERR=801) temp
    READ(temp,*) sgroup
    !
  ELSEIF( temp(1:5)=="SYMOP" ) THEN
    !Count symmetry operations
    Nsym = 0
    DO
      READ(30,'(a128)',END=801,ERR=801) temp
      READ(temp,*,END=110,ERR=110) (symops_line(j) , j=1,12)
      Nsym = Nsym+1
    ENDDO
  ENDIF
  110 CONTINUE
  !
ENDDO
!
!
!
200 CONTINUE
WRITE(msg,*) 'Number of atoms: ', NP
CALL ATOMSK_MSG(999,(/msg/),(/0.d0/))
IF( NP<=0 ) THEN
  !Number of particles is zero => we have a problem, abort
  CALL ATOMSK_MSG(804,(/''/),(/0.d0/))
  nerr = nerr+1
  GOTO 1000
ENDIF
!
ALLOCATE( P(NP,4) )
P(:,:) = 0.d0
ALLOCATE(AUXNAMES(4))
AUXNAMES(1) = "occ"
AUXNAMES(2) = "fx"
AUXNAMES(3) = "fy"
AUXNAMES(4) = "fz"
ALLOCATE(AUX(NP,4))
AUX(:,:) = 0.d0
!
!Go back to beginning of file
REWIND(30)
!
!Read and store atomic data
DO
  READ(30,'(a128)',END=300,ERR=300) temp
  temp = ADJUSTL(temp)
  !
  IF( temp(1:5)=="STRUC" ) THEN
    !Read atomic data
    DO WHILE( temp(1:5).NE."0 0 0" )
      !Each atom has two lines of data
      !First line contains atom index, species, position
      READ(30,'(a128)',END=800,ERR=800) temp
      temp = ADJUSTL(temp)
      READ(temp,*,END=800,ERR=800) i
      READ(temp,*,END=800,ERR=800) i, species, temp2, occ, P1, P2, P3
      IF( i>0 .AND. i<=SIZE(P,1) ) THEN
        P(i,1) = P1
        P(i,2) = P2
        P(i,3) = P3
        CALL ATOMNUMBER(species,P(i,4))
        !auxiliary properties
        AUX(i,1) = occ
      ENDIF
      !
      !Second line contains vector
      READ(30,'(a128)',END=220,ERR=220) temp2
      READ(temp2,*,END=220,ERR=220) P1, P2, P3
      AUX(i,2) = P1
      AUX(i,3) = P2
      AUX(i,4) = P3
      !
      220 CONTINUE
    ENDDO
    290 CONTINUE
    EXIT
    !
  ELSEIF( temp(1:5)=="SYMOP" ) THEN
    !Read and store symmetry operations
    IF( Nsym>0 ) THEN
      IF(ALLOCATED(symops_trf)) DEALLOCATE(symops_trf)
      ALLOCATE(symops_trf(12,Nsym))
      symops_trf(:,:) = 0.d0
      DO i=1,Nsym
        READ(30,'(a128)',END=801,ERR=801) temp
        READ(temp,*,END=802,ERR=802) (symops_trf(j,i) , j=1,12)
      ENDDO
    ENDIF
  ENDIF
  !
ENDDO
!
!
!
300 CONTINUE
!Convert coordinates from fractional to cartesian
CALL FRAC2CART(P,H)
!Apply symmetry operations (if any)
!(cf. /include/symops.f90)
IF( Nsym>0 ) THEN
  CALL SYMOPS_APPLY(H,P,S,AUXNAMES,AUX,1.d0,j)
  IF(ALLOCATED(symops_trf)) DEALLOCATE(symops_trf)
ENDIF
GOTO 1000
!
!
!
800 CONTINUE
CALL ATOMSK_MSG(802,(/''/),(/DBLE(i)/))
nerr = nerr+1
GOTO 1000
!
801 CONTINUE
CALL ATOMSK_MSG(1809,(/''/),(/0.d0/))
nerr = nerr+1
GOTO 1000
!
802 CONTINUE
CALL ATOMSK_MSG(1813,(/TRIM(temp)/),(/0.d0/))
nerr = nerr+1
GOTO 1000
!
!
!
1000 CONTINUE
CLOSE(30)
!
!
END SUBROUTINE READ_VESTA
!
END MODULE in_vesta
